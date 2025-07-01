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
import {ReentrancyGuardUpgradeableWithViewModifier} from "@src/helpers/ReentrancyGuardUpgradeableWithViewModifier.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {IAaveAdapter} from "@src/market/token/adapters/IAaveAdapter.sol";
import {IAdapter} from "@src/market/token/adapters/IAdapter.sol";

address constant DEFAULT_VAULT = address(0);

/// @title NonTransferrableRebasingTokenVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A non-transferrable rebasing ERC-20 token vault
///         This token vault deposits underlying tokens into vaults on behalf of users
///           and mints shares to represent their underlying balances. Currently, only Aave and ERC4626 vaults are supported.
/// @dev This contract was upgraded from NonTransferrableScaledTokenV1_5 in v1.8
///      By default, underlying tokens are deposited into the Aave pool, unless the user has set a ERC4626 vault.
///      Vaults are whitelisted, and are assumed to be standard ERC4626 tokens.
///      Vaults with features such as pause, fee on transfer, and asynchronous share minting/burning are not supported.
///      The contract owner configures a vault adapter that implements the `IAdapter` interface to handle deposit/withdraw/etc logic for each vault that is whitelisted.
///        Currently, only Aave and ERC4626 vaults are supported, but this can be extended to other vault types by the contract owner.
///      Functions are `virtual` to allow for custom logic in test contracts.
contract NonTransferrableRebasingTokenVault is
    IERC20Metadata,
    IERC20Errors,
    Ownable2StepUpgradeable,
    ReentrancyGuardUpgradeableWithViewModifier,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20Metadata;
    using EnumerableMap for EnumerableMap.AddressToBytes32Map;
    using EnumerableMap for EnumerableMap.Bytes32ToAddressMap;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    // slither-disable-start uninitialized-state
    // slither-disable-start constable-states
    // v1.5
    ISizeFactory public sizeFactory;
    IPool public aavePool;
    IERC20Metadata public underlyingToken;
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private ___unused__scaledTotalSupply; // deprecated in v1.8
    mapping(address user => uint256 shares) public sharesOf; // updated in v1.8
    // v1.8
    mapping(address user => address vault) public vaultOf;
    EnumerableMap.AddressToBytes32Map internal vaultToIdMap;
    EnumerableMap.Bytes32ToAddressMap internal IdToAdapterMap;
    EnumerableMap.AddressToBytes32Map internal adapterToIdMap;
    // slither-disable-end constable-states
    // slither-disable-end uninitialized-state

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SharesSet(address indexed user, uint256 indexed previousShares, uint256 indexed newShares);
    event VaultSet(address indexed user, address indexed previousVault, address indexed newVault);
    event VaultAdapterSet(address indexed vault, bytes32 indexed id);
    event VaultRemoved(address indexed vault);
    event AdapterSet(bytes32 indexed id, address indexed adapter);
    event AdapterRemoved(bytes32 indexed id, address indexed adapter);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyMarket() {
        if (!sizeFactory.isMarket(msg.sender)) {
            revert Errors.UNAUTHORIZED(msg.sender);
        }
        _;
    }

    modifier onlyAdapter() {
        if (!adapterToIdMap.contains(msg.sender)) {
            revert Errors.UNAUTHORIZED(msg.sender);
        }
        _;
    }

    modifier onlyAdapterId(bytes32 id) {
        if (adapterToIdMap.get(msg.sender) != id) {
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

    /// @dev Changing the IAdapter requires a reset in AToken approvals
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
        __ReentrancyGuard_init();
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
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Changing the IAdapter requires a reset in AToken approvals
    function reinitialize(string memory name_, string memory symbol_, IAaveAdapter aaveAdapter, IAdapter erc4626Adapter)
        external
        onlyOwner
        reinitializer(1_08_00)
    {
        name = name_;
        symbol = symbol_;

        __ReentrancyGuard_init();

        _setAdapter(bytes32("AaveAdapter"), aaveAdapter);
        _setVaultAdapter(DEFAULT_VAULT, bytes32("AaveAdapter"));

        _setAdapter(bytes32("ERC4626Adapter"), erc4626Adapter);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @notice Sets the adapter with id
    /// @dev The adapter contract must be trusted, since it can call sensitive functions guarded by the `onlyAdapter` modifier
    ///      If an adapter is already set, it will be removed and replaced with the new adapter
    function setAdapter(bytes32 id, IAdapter adapter) external onlyOwner {
        _setAdapter(id, adapter);
    }

    /// @notice Removes the adapter
    /// @dev Removing an adapter will brick the vault
    function removeAdapter(bytes32 id) external onlyOwner {
        _removeAdapter(id);
    }

    /// @notice Sets the adapter for a vault
    /// @dev Setting a wrong adapter may brick the vault (`IAdapter` functions may revert or return incorrect values)
    function setVaultAdapter(address vault, bytes32 id) external onlyOwner {
        _setVaultAdapter(vault, id);
    }

    /// @notice Removes a vault from the whitelist
    /// @dev Removing a vault will brick the vault (all `IAdapter` functions will revert,
    ///        and `vaultToIdMap.at()` will not return the vault, so `totalSupply()` will ignore it)
    function removeVault(address vault) external onlyOwner {
        _removeVault(vault);
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IERC20
    /// @dev The `value` amount received may be lower than the input amount due to rounding.
    ///      In cases where `from` and `to` have the same vault, an internal transfer is performed in order to save gas and avoid potential fees.
    ///        This can be used to "exit" from vaults that are compromised or paused, which is a known tradeoff acknowledged by users.
    ///      In cases where `from` and `to` have different vaults, the `value` amount is first withdrawn and then deposited, with exact input,
    ///        otherwise, the recipient could receive fewer assets due to fees from the sender's vault.
    function transferFrom(address from, address to, uint256 value)
        public
        virtual
        onlyMarket
        nonReentrant
        returns (bool)
    {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        if (value > 0) {
            if (vaultOf[from] == vaultOf[to]) {
                IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[from]);
                adapter.transferFrom(vaultOf[from], from, to, value);
            } else {
                IAdapter adapterFrom = getWhitelistedVaultAdapter(vaultOf[from]);
                IAdapter adapterTo = getWhitelistedVaultAdapter(vaultOf[to]);
                // slither-disable-next-line unused-return
                adapterFrom.withdraw(vaultOf[from], from, address(adapterTo), value);
                // slither-disable-next-line unused-return
                adapterTo.deposit(vaultOf[to], to, value);
                adapterTo.checkLiquidity(vaultOf[to], value);
            }
        }

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
    function balanceOf(address account) public view nonReentrantView returns (uint256) {
        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[account]);
        return adapter.balanceOf(vaultOf[account], account);
    }

    /// @inheritdoc IERC20
    /// @dev This method has O(n) complexity, where n is the number of whitelisted vaults, and should not be used onchain
    ///      The invariant `SUM(balanceOf) == totalSupply()` may not hold true due to rounding errors in scaled amounts/shares accounting.
    ///        However, we should still have `SUM(balanceOf) <= totalSupply()`, since `balanceOf` rounds down, and also to guarantee the solvency of the protocol.
    // slither-disable-next-line calls-loop
    function totalSupply() public view nonReentrantView returns (uint256) {
        uint256 assets = 0;
        for (uint256 i = 0; i < vaultToIdMap.length(); i++) {
            // slither-disable-next-line unused-return
            (address vault,) = vaultToIdMap.at(i);
            IAdapter adapter = getWhitelistedVaultAdapter(vault);
            assets += adapter.totalSupply(vault);
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
    ///        from the previous vault and deposit them into the new vault. This can revert during both
    ///        `IAdapter.fullWithdraw` and `IAdapter.deposit`, for example if the user has a small amount of shares
    ///        in the previous vault and would receive 0 assets, or if the new vault would mint 0 shares, or if the vaults are paused, etc.
    ///      If `forfeitOldShares` is true, the user's old shares are forfeited and the user's balance is reset to 0.
    ///        This can be used to recover from compromised or removed vaults, allowing users to move their positions
    ///        to a different vault without requiring interaction with the old vault, which may be inaccessible or
    ///        compromised. This prevents users from being permanently locked out of the protocol when their chosen
    ///        vault becomes unavailable.
    ///      If the user changes vaults while having shares, the user's shares must first reset to 0 before `IAdapter.deposit`
    ///        to avoid leaving dust behind. This is important because small residual share amounts (due to rounding)
    ///        can lead to inconsistencies when the user changes vaults. For example, if the user switches to a new
    ///        vault but still holds a dust amount of shares in the previous one, the underlying tokens held by the new
    ///        vault may not accurately reflect the current vault assignment, leading to misattribution of assets.
    ///        See https://slowmist.medium.com/slowmist-aave-v2-security-audit-checklist-0d9ef442436b#5aed
    // slither-disable-next-line reentrancy-no-eth
    function setVault(address user, address vault, bool forfeitOldShares) public virtual onlyMarket nonReentrant {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        } else if (!vaultToIdMap.contains(vault)) {
            revert Errors.INVALID_VAULT(vault);
        } else if (vaultOf[user] != vault) {
            if (forfeitOldShares) {
                _setSharesOf(user, 0);
            } else if (sharesOf[user] > 0) {
                IAdapter adapterOld = getWhitelistedVaultAdapter(vaultOf[user]);
                IAdapter adapterNew = getWhitelistedVaultAdapter(vault);
                uint256 assetsWithdrawn = adapterOld.fullWithdraw(vaultOf[user], user, address(adapterNew));
                if (assetsWithdrawn > 0) {
                    uint256 assetsDeposited = adapterNew.deposit(vault, user, assetsWithdrawn);
                    if (assetsWithdrawn > assetsDeposited) {
                        emit Transfer(user, address(0), assetsWithdrawn - assetsDeposited);
                    } else if (assetsDeposited > assetsWithdrawn) {
                        emit Transfer(address(0), user, assetsDeposited - assetsWithdrawn);
                    }
                }
            }
            _setVaultOf(user, vault);
        } else {
            revert Errors.INVALID_VAULT(vault);
        }
    }

    /// @notice Deposit underlying tokens into the variable pool and mint scaled tokens
    /// @dev The actual deposited amount can be lower than the input amount based on the vault deposit and rounding logic
    function deposit(address to, uint256 amount) public virtual onlyMarket nonReentrant returns (uint256 assets) {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[to]);
        underlyingToken.safeTransferFrom(msg.sender, address(adapter), amount);
        assets = adapter.deposit(vaultOf[to], to, amount);

        emit Transfer(address(0), to, assets);
    }

    /// @notice Withdraw underlying tokens from the vault and burn shares
    /// @dev The actual withdrawn amount can be lower than the input amount based on the vault withdraw and rounding logic.
    function withdraw(address from, address to, uint256 amount)
        public
        virtual
        onlyMarket
        nonReentrant
        returns (uint256 assets)
    {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[from]);
        assets = adapter.withdraw(vaultOf[from], from, to, amount);

        emit Transfer(from, address(0), assets);
    }

    /// @notice Withdraws all assets from the vault and sets shares to zero
    function fullWithdraw(address from, address to) public virtual onlyMarket nonReentrant returns (uint256 assets) {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        IAdapter adapter = getWhitelistedVaultAdapter(vaultOf[from]);
        assets = adapter.fullWithdraw(vaultOf[from], from, to);

        emit Transfer(from, address(0), assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ADAPTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the shares of a user
    /// @dev Only callable by the adapter
    ///      Adapter helper functions operate via reentrancy, so they do not have the nonReentrant modifier
    function setSharesOf(address user, uint256 shares) public onlyAdapter {
        _setSharesOf(user, shares);
    }

    /// @notice Increases the allowance of the vault
    /// @dev Only callable by the adapter
    ///      Adapter helper functions operate via reentrancy, so they do not have the nonReentrant modifier
    function requestApprove(address vault, uint256 amount) public onlyAdapter {
        IERC20Metadata(vault).forceApprove(msg.sender, amount);
    }

    /// @notice Requests a withdraw from the Aave pool
    /// @dev Only callable by the adapter
    ///      Adapter helper functions operate via reentrancy, so they do not have the nonReentrant modifier
    ///      This function is utilized instead of `requestApprove` in order to avoid an extra `AToken.transferFrom` call, which can cause rounding errors due to WadRay math.
    function requestAaveWithdraw(uint256 amount, address to) public onlyAdapterId("AaveAdapter") {
        // slither-disable-next-line unused-return
        aavePool.withdraw(address(underlyingToken), amount, to);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return IAaveAdapter(address(getWhitelistedVaultAdapter(DEFAULT_VAULT))).liquidityIndex();
    }

    /// @notice Returns true if the vault is whitelisted
    function isWhitelistedVault(address vault) public view returns (bool) {
        return vaultToIdMap.contains(vault);
    }

    /// @notice Returns the number of whitelisted vaults
    function getWhitelistedVaultsCount() public view returns (uint256) {
        return vaultToIdMap.length();
    }

    /// @notice Returns the whitelisted vault at the given index
    function getWhitelistedVault(uint256 index) public view returns (address vault, address adapter, bytes32 id) {
        (vault, id) = vaultToIdMap.at(index);
        adapter = IdToAdapterMap.get(id);
    }

    /// @notice Returns all whitelisted vaults
    function getWhitelistedVaults()
        public
        view
        returns (address[] memory vaults, address[] memory adapters, bytes32[] memory ids)
    {
        vaults = new address[](vaultToIdMap.length());
        adapters = new address[](vaultToIdMap.length());
        ids = new bytes32[](vaultToIdMap.length());
        for (uint256 i = 0; i < vaultToIdMap.length(); i++) {
            (vaults[i], adapters[i], ids[i]) = getWhitelistedVault(i);
        }
    }

    /// @notice Returns the adapter for a vault
    function getWhitelistedVaultAdapter(address vault) public view returns (IAdapter) {
        bytes32 id = vaultToIdMap.get(vault);
        return IAdapter(IdToAdapterMap.get(id));
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets the adapter
    // slither-disable-start unused-return
    function _setAdapter(bytes32 id, IAdapter adapter) private {
        if (address(adapter) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (IdToAdapterMap.contains(id)) {
            _removeAdapter(id);
        }

        IdToAdapterMap.set(id, address(adapter));
        adapterToIdMap.set(address(adapter), id);
        emit AdapterSet(id, address(adapter));
    }
    // slither-disable-end unused-return

    /// @notice Removes the adapter
    function _removeAdapter(bytes32 id) private {
        address adapter = IdToAdapterMap.get(id);
        bool removed = IdToAdapterMap.remove(id);
        removed = adapterToIdMap.remove(adapter);

        if (removed) {
            emit AdapterRemoved(id, adapter);
        }
    }

    /// @notice Sets the adapter for a vault
    /// @dev Setting the vault to `address(0)` will use the default variable pool
    function _setVaultAdapter(address vault, bytes32 id) private {
        IAdapter adapter = IAdapter(IdToAdapterMap.get(id));
        adapter.validate(vault);

        // slither-disable-next-line unused-return
        vaultToIdMap.set(vault, id);
        emit VaultAdapterSet(vault, id);
    }

    /// @notice Removes a vault from the whitelist
    function _removeVault(address vault) private {
        bool removed = vaultToIdMap.remove(vault);
        if (removed) {
            emit VaultRemoved(vault);
        }
    }

    /// @notice Sets the vault of a user
    function _setVaultOf(address user, address vault) internal virtual {
        emit VaultSet(user, vaultOf[user], vault);
        vaultOf[user] = vault;
    }

    /// @notice Sets the shares of a user
    function _setSharesOf(address user, uint256 shares) internal virtual {
        emit SharesSet(user, sharesOf[user], shares);
        sharesOf[user] = shares;
    }
}
