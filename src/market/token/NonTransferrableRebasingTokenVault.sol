// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

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
    IERC20Metadata,
    IERC20Errors,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS 
    //////////////////////////////////////////////////////////////*/

    address public constant DEFAULT_VAULT = address(0);

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    // v1.5
    ISizeFactory public sizeFactory;
    IPool public aavePool;
    IERC20Metadata public underlyingToken;

    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public scaledTotalSupply;
    mapping(address user => uint256 scaledBalance) public scaledBalanceOf;

    // v1.8
    mapping(address user => address vault) public vaultOf;
    mapping(address user => uint256 shares) public sharesOf;
    EnumerableSet.AddressSet private whitelistedVaults;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event VaultSet(address indexed user, address indexed previousVault, address indexed newVault);
    event VaultWhitelisted(address indexed vault, bool indexed previousWhitelisted, bool indexed newWhitelisted);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyMarket();
    error InsufficientTotalAssets(address vault, uint256 totalAssets, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyMarket() {
        if (!sizeFactory.isMarket(msg.sender)) {
            revert Errors.UNAUTHORIZED(msg.sender);
        }
        _;
    }

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

        sizeFactory = sizeFactory_;

        aavePool = aavePool_;
        underlyingToken = underlyingToken_;

        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        // v1.8
        _setVaultWhitelisted(DEFAULT_VAULT, true);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function reinitialize(string memory name_, string memory symbol_) external onlyOwner reinitializer(1_08_00) {
        name = name_;
        symbol = symbol_;

        // v1.8
        _setVaultWhitelisted(DEFAULT_VAULT, true);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setVaultWhitelisted(address vault, bool whitelisted) external onlyOwner {
        _setVaultWhitelisted(vault, whitelisted);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20
    function transferFrom(address from, address to, uint256 value) public virtual onlyMarket returns (bool) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        // slither-disable-next-line unused-return
        _transferFrom(from, to, value, vaultOf[from], vaultOf[to]);

        emit Transfer(from, to, value);
        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @inheritdoc IERC20
    function allowance(address, address spender) public view virtual override returns (uint256) {
        return sizeFactory.isMarket(spender) ? type(uint256).max : 0;
    }

    /// @inheritdoc IERC20
    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view returns (uint256) {
        address vault = vaultOf[account];
        if (vault == DEFAULT_VAULT) {
            return _unscale(scaledBalanceOf[account]);
        } else {
            return IERC4626(vault).convertToAssets(sharesOf[account]);
        }
    }

    /// @inheritdoc IERC20
    /// @dev This method has O(n) complexity, where n is the number of whitelisted vaults, and should not be used onchain
    function totalSupply() public view returns (uint256) {
        uint256 assets = 0;
        for (uint256 i = 0; i < whitelistedVaults.length(); i++) {
            address vault = whitelistedVaults.at(i);
            if (vault == DEFAULT_VAULT) {
                IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);
                assets += aToken.balanceOf(address(this));
            } else {
                assets += IERC4626(vault).maxWithdraw(address(this));
            }
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
        if (whitelistedVaults.contains(address(vault)) && vaultOf[user] != vault) {
            _transferFrom(user, user, balanceOf(user), vaultOf[user], vault);

            emit VaultSet(user, vaultOf[user], vault);
            vaultOf[user] = vault;
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

        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        assets = _deposit(from, to, amount, vaultOf[to]);

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

        assets = _withdraw(from, to, amount, vaultOf[from]);

        emit Transfer(from, address(0), assets);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return aavePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    /// @notice Returns true if the vault is whitelisted
    function isWhitelistedVault(address vault) public view returns (bool) {
        return whitelistedVaults.contains(vault);
    }

    /// @notice Returns the number of whitelisted vaults
    function getWhitelistedVaultsCount() public view returns (uint256) {
        return whitelistedVaults.length();
    }

    /// @notice Returns the whitelisted vault at the given index
    function getWhitelistedVault(uint256 index) public view returns (address) {
        return whitelistedVaults.at(index);
    }

    /// @notice Returns all whitelisted vaults
    function getWhitelistedVaults() public view returns (address[] memory) {
        return whitelistedVaults.values();
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits underlying tokens into an ERC4626 vault or the Aave pool
    function _deposit(address from, address to, uint256 amount, address vault) private returns (uint256 assets) {
        if (vault == DEFAULT_VAULT) {
            assets = _depositToAave(from, to, amount);
        } else {
            assets = _depositToERC4626Vault(from, to, amount, IERC4626(vault));
        }
    }

    /// @notice Withdraws underlying tokens from an ERC4626 vault or the Aave pool
    function _withdraw(address from, address to, uint256 amount, address vault) private returns (uint256 assets) {
        bool fullWithdraw = amount == balanceOf(from);
        if (vault == DEFAULT_VAULT) {
            assets = _withdrawFromAave(from, to, amount, fullWithdraw);
        } else {
            assets = _withdrawFromERC4626Vault(from, to, amount, fullWithdraw, IERC4626(vault));
        }
    }

    /// @notice Transfers underlying tokens between users (ERC4626 vaults or Aave)
    /// @dev If the amount is 0, short circuit, as some ERC4626 vaults revert on 0 deposit/withdraw/transfer
    function _transferFrom(address from, address to, uint256 value, address vaultFrom, address vaultTo)
        private
        returns (uint256 assets)
    {
        // slither-disable-next-line incorrect-equality
        if (value == 0) return 0;

        if (vaultFrom == vaultTo) {
            if (vaultFrom == DEFAULT_VAULT) {
                assets = _transferFromAaveSame(from, to, value);
            } else {
                assets = _transferFromERC4626VaultSame(from, to, value, IERC4626(vaultFrom));
            }
        } else {
            assets = _withdraw(from, address(this), value, vaultFrom);
            assets = _deposit(address(this), to, assets, vaultTo);
        }
    }

    /// @notice Deposits underlying tokens into an ERC4626 vault
    // slither-disable-next-line reentrancy-benign
    function _depositToERC4626Vault(address, address to, uint256 amount, IERC4626 vault)
        private
        returns (uint256 assets)
    {
        underlyingToken.forceApprove(address(vault), amount);

        uint256 sharesBefore = vault.balanceOf(address(this));

        // slither-disable-next-line unused-return
        vault.deposit(amount, address(this));

        uint256 shares = vault.balanceOf(address(this)) - sharesBefore;
        assets = vault.convertToAssets(shares);

        sharesOf[to] += shares;
    }

    /// @notice Deposits underlying tokens into the Aave pool
    // slither-disable-next-line reentrancy-benign
    function _depositToAave(address, address to, uint256 amount) private returns (uint256 assets) {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 sharesBefore = aToken.scaledBalanceOf(address(this));

        underlyingToken.forceApprove(address(aavePool), amount);
        aavePool.supply(address(underlyingToken), amount, address(this), 0);

        uint256 shares = aToken.scaledBalanceOf(address(this)) - sharesBefore;
        assets = _unscale(shares);

        scaledTotalSupply += shares;
        scaledBalanceOf[to] += shares;
    }

    /// @notice Withdraws underlying tokens from an ERC4626 vault
    // slither-disable-next-line reentrancy-benign
    function _withdrawFromERC4626Vault(address from, address to, uint256 amount, bool fullWithdraw, IERC4626 vault)
        private
        returns (uint256 assets)
    {
        uint256 sharesBefore = vault.balanceOf(address(this));
        uint256 assetsBefore = underlyingToken.balanceOf(address(this));

        // slither-disable-next-line unused-return
        vault.withdraw(amount, address(this), address(this));

        uint256 shares = sharesBefore - vault.balanceOf(address(this));
        assets = underlyingToken.balanceOf(address(this)) - assetsBefore;

        underlyingToken.safeTransfer(to, assets);

        if (fullWithdraw) {
            uint256 dust = sharesOf[from] - shares;
            sharesOf[from] = 0;
            sharesOf[owner()] += dust;
        } else {
            sharesOf[from] -= shares;
        }
    }

    /// @notice Withdraws underlying tokens from the Aave pool
    // slither-disable-next-line reentrancy-benign
    function _withdrawFromAave(address from, address to, uint256 amount, bool fullWithdraw)
        private
        returns (uint256 assets)
    {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        aavePool.withdraw(address(underlyingToken), amount, to);

        uint256 shares = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));
        assets = _unscale(shares);

        if (scaledBalanceOf[from] < shares) {
            revert ERC20InsufficientBalance(from, balanceOf(from), amount);
        }

        if (fullWithdraw) {
            uint256 dust = scaledBalanceOf[from] - shares;
            scaledBalanceOf[from] = 0;
            scaledBalanceOf[owner()] += dust;
        } else {
            scaledBalanceOf[from] -= shares;
        }
        scaledTotalSupply -= shares;
    }

    /// @notice Transfers assets between an ERC4626 vault and the same ERC4626 vault
    /// @dev The assets are converted to shares and then transferred internally
    ///      The share amount is rounded down
    function _transferFromERC4626VaultSame(address from, address to, uint256 value, IERC4626 vault)
        private
        returns (uint256 assets)
    {
        if (vault.totalAssets() < value) {
            revert InsufficientTotalAssets(address(vault), vault.totalAssets(), value);
        }

        uint256 shares = vault.convertToShares(value);
        assets = value;

        if (sharesOf[from] < shares) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        sharesOf[from] -= shares;
        sharesOf[to] += shares;
    }

    /// @notice Transfers underlying tokens between the users using Aave as their vault choice
    /// @dev The underlying tokens are converted to scaled tokens and then transferred internally
    ///      The scaled amount is rounded down
    ///      If the Aave pool has insufficient liquidity, the ERC20InsufficientTotalAssets error is thrown with DEFAULT_VAULT as the vault parameter,
    ///        even though the underlying balance is checked against the Aave pool
    function _transferFromAaveSame(address from, address to, uint256 value) private returns (uint256 assets) {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);
        if (underlyingToken.balanceOf(address(aToken)) < value) {
            revert InsufficientTotalAssets(address(DEFAULT_VAULT), underlyingToken.balanceOf(address(aToken)), value);
        }

        uint256 shares = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());
        assets = value;

        if (scaledBalanceOf[from] < shares) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        scaledBalanceOf[from] -= shares;
        scaledBalanceOf[to] += shares;
    }

    /// @notice Unscales a scaled amount
    /// @return The unscaled amount
    /// @dev The unscaled amount is the scaled amount divided by the current liquidity index
    function _unscale(uint256 scaledAmount) private view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Sets the whitelist status of a vault
    function _setVaultWhitelisted(address vault, bool whitelisted) private {
        bool previousWhitelisted = whitelistedVaults.contains(vault);
        emit VaultWhitelisted(vault, previousWhitelisted, whitelisted);
        if (whitelisted) {
            if (vault != DEFAULT_VAULT && IERC4626(vault).asset() != address(underlyingToken)) {
                revert Errors.INVALID_VAULT(address(vault));
            }

            whitelistedVaults.add(address(vault));
        } else {
            whitelistedVaults.remove(address(vault));
        }
    }
}
