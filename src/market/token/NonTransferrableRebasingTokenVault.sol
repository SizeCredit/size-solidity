// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {
    DEFAULT_VAULT,
    NonTransferrableRebasingTokenVaultBase,
    Storage
} from "@src/market/token/NonTransferrableRebasingTokenVaultBase.sol";
import {Adapter, BaseAdapter} from "@src/market/token/adapters/BaseAdapter.sol";

/// @title NonTransferrableRebasingTokenVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A non-transferrable rebasing ERC-20 token vault
///         This token vault deposits underlying tokens into Aave or ERC4626 vaults on behalf of users
///           and mints scaled tokens or shares to users representing their underlying token amount.
/// @dev This contract was upgraded from NonTransferrableScaledTokenV1_5 in v1.8
///      By default, underlying tokens are deposited into the Aave pool, unless the user has set a ERC4626 vault.
///      Vaults are whitelisted, and are assumed to be standard ERC4626 tokens.
///      Vaults with features such as pause, fee on transfer, and asynchronous share minting/burning are not supported.
contract NonTransferrableRebasingTokenVault is
    NonTransferrableRebasingTokenVaultBase,
    IERC20Metadata,
    IERC20Errors,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20Metadata;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using BaseAdapter for Storage;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR/INITIALIZER
    //////////////////////////////////////////////////////////////*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        ISizeFactory sizeFactory_,
        IPool aavePool_,
        IERC20Metadata underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external initializer {
        __Ownable_init(owner_);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();

        if (
            address(sizeFactory_) == address(0) || address(aavePool_) == address(0)
                || address(underlyingToken_) == address(0)
        ) {
            revert Errors.NULL_ADDRESS();
        }

        s.sizeFactory = sizeFactory_;

        s.aavePool = aavePool_;
        s.underlyingToken = underlyingToken_;

        s.name = name_;
        s.symbol = symbol_;
        s.decimals = decimals_;

        // v1.8
        _setVaultAdapter(DEFAULT_VAULT, Adapter.Aave);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function reinitialize(string memory name_, string memory symbol_) external onlyOwner reinitializer(1_08_00) {
        s.name = name_;
        s.symbol = symbol_;

        // v1.8
        _setVaultAdapter(DEFAULT_VAULT, Adapter.Aave);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setVaultAdapter(address vault, Adapter adapter) external onlyOwner {
        _setVaultAdapter(vault, adapter);
    }

    function removeVault(address vault) external onlyOwner {
        _removeVault(vault);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20Metadata
    function name() public view override returns (string memory) {
        return s.name;
    }

    /// @inheritdoc IERC20Metadata
    function symbol() public view override returns (string memory) {
        return s.symbol;
    }

    /// @inheritdoc IERC20Metadata
    function decimals() public view override returns (uint8) {
        return s.decimals;
    }

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 value) public virtual onlyMarket returns (bool) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        address vaultFrom = s.vaultOf[from];
        address vaultTo = s.vaultOf[to];
        _transferFrom(vaultFrom, vaultTo, from, to, value);

        emit Transfer(from, to, value);

        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @inheritdoc IERC20
    function allowance(address, address spender) public view virtual override returns (uint256) {
        return s.sizeFactory.isMarket(spender) ? type(uint256).max : 0;
    }

    /// @inheritdoc IERC20
    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view returns (uint256) {
        return s.balanceOf(s.vaultOf[account], account);
    }

    /// @inheritdoc IERC20
    /// @dev This method has O(n) complexity, where n is the number of whitelisted vaults, and should not be used onchain
    ///      The invariant SUM(balanceOf) == totalSupply() may not hold true due to rounding errors in scaled amounts/shares accounting.
    ///        However, we should still have SUM(balanceOf) <= totalSupply() since balanceOf() rounds down, and also to guarantee the solvency of the protocol.
    // slither-disable-next-line calls-loop
    function totalSupply() public view returns (uint256) {
        uint256 assets = 0;
        for (uint256 i = 0; i < s.vaultToAdapterMap.length(); i++) {
            (address vault,) = s.vaultToAdapterMap.at(i);
            assets += s.totalSupply(vault);
        }
        return assets;
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the vault
    /// @dev This function is only callable by the market
    ///      Setting the vault to `address(0)` will use the default variable pool
    ///      Setting the vault to a different address will withdraw all the user's assets
    ///        from the previous vault and deposit them into the new vault
    ///      Reverts if the vault asset is not the same as the NonTransferrableRebasingTokenVault's underlying token
    function setVault(address user, address vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (s.vaultToAdapterMap.contains(address(vault)) && s.vaultOf[user] != vault) {
            _transferFrom(s.vaultOf[user], vault, user, user, balanceOf(user));

            emit VaultSet(user, s.vaultOf[user], vault);
            s.vaultOf[user] = vault;
        }
    }

    /// @notice Deposit underlying tokens into the variable pool and mint scaled tokens
    /// @dev The actual deposited amount can be lower than the input amount based on the vault deposit and rounding logic
    function deposit(address from, address to, uint256 amount) external onlyMarket returns (uint256 assets) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        s.underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        assets = s.deposit(s.vaultOf[to], from, to, amount);

        emit Transfer(address(0), to, assets);
    }

    /// @notice Withdraw underlying tokens from the variable pool and burn scaled tokens
    /// @dev The actual withdrawn amount can be lower than the input amount based on the vault withdraw and rounding logic.
    ///      If `amount` is equal to the user's `balanceOf`, a full withdrawal is performed
    ///        and the user's shares in the vault are reset to 0 to avoid leaving dust behind.
    ///        This is important because small residual share amounts (due to rounding) can lead to
    ///        inconsistencies when the user changes vaults. For example, if the user switches to a new
    ///        vault but still holds a dust amount of shares in the previous one, the underlying tokens
    ///        held by the new vault may not accurately reflect the current vault assignment, leading to
    ///        misattribution of assets. The dust is sent to the owner.
    ///        See https://slowmist.medium.com/slowmist-aave-v2-security-audit-checklist-0d9ef442436b#5aed
    function withdraw(address from, address to, uint256 amount) external onlyMarket returns (uint256 assets) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        assets = s.withdraw(s.vaultOf[from], from, to, amount);

        emit Transfer(from, address(0), assets);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function vaultOf(address user) public view returns (address) {
        return s.vaultOf[user];
    }

    function sharesOf(address user) public view returns (uint256) {
        return s.sharesOf[user];
    }

    function scaledBalanceOf(address user) public view returns (uint256) {
        return s.scaledBalanceOf[user];
    }

    function scaledTotalSupply() public view returns (uint256) {
        return s.scaledTotalSupply;
    }

    function sizeFactory() public view returns (ISizeFactory) {
        return s.sizeFactory;
    }

    function aavePool() public view returns (IPool) {
        return s.aavePool;
    }

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return s.pricePerShare(DEFAULT_VAULT);
    }

    /// @notice Returns true if the vault is whitelisted
    function isWhitelistedVault(address vault) public view returns (bool) {
        return s.vaultToAdapterMap.contains(vault);
    }

    /// @notice Returns the number of whitelisted vaults
    function getWhitelistedVaultsCount() public view returns (uint256) {
        return s.vaultToAdapterMap.length();
    }

    /// @notice Returns the whitelisted vault at the given index
    function getWhitelistedVault(uint256 index) public view returns (address, Adapter) {
        (address vault, uint256 adapter) = s.vaultToAdapterMap.at(index);
        return (vault, Adapter(adapter));
    }

    /// @notice Returns all whitelisted vaults
    function getWhitelistedVaults() public view returns (address[] memory vaults, Adapter[] memory adapters) {
        vaults = new address[](s.vaultToAdapterMap.length());
        adapters = new Adapter[](s.vaultToAdapterMap.length());
        for (uint256 i = 0; i < s.vaultToAdapterMap.length(); i++) {
            (address vault, uint256 adapter) = s.vaultToAdapterMap.at(i);
            vaults[i] = vault;
            adapters[i] = Adapter(adapter);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the adapter for a vault
    /// @dev Sets the adapter first so that s.getAsset(vault) is available
    function _setVaultAdapter(address vault, Adapter adapter) private {
        s.vaultToAdapterMap.set(vault, uint256(adapter));
        emit VaultAdapterSet(vault, uint256(adapter));

        if (s.getAsset(vault) != address(s.underlyingToken)) {
            revert Errors.INVALID_VAULT(address(vault));
        }
    }

    function _removeVault(address vault) private {
        s.vaultToAdapterMap.remove(vault);
        emit VaultRemoved(vault);
    }

    function _transferFrom(address vaultFrom, address vaultTo, address from, address to, uint256 value) private {
        if (value > 0) {
            if (vaultFrom == vaultTo) {
                s.transferFrom(vaultFrom, from, to, value);
            } else {
                /* slither-disable unused-return */
                s.withdraw(vaultFrom, from, address(this), value);
                s.deposit(vaultTo, address(this), to, value);
                /* slither-enable unused-return */
            }
        }
    }
}
