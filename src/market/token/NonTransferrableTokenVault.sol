// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

/// @title NonTransferrableTokenVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol. This vault holds Aave's aTokens and ERC4626 tokens on behalf of users and mints
///         a rebasing ERC20 deposit token to users representing their underlying token amount.
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
///      This contract was upgraded from NonTransferrableScaledTokenV1_5 in v1.8
///      By default, underlying tokens are deposited into the Aave pool, unless the user has set a vault
///      User vaults are untrusted. TODO: do we need to put reentrancy guards everywhere???
contract NonTransferrableTokenVault is IERC20Metadata, IERC20Errors, Ownable2StepUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20Metadata;

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
    mapping(address user => IERC4626 vault) public userVault;
    mapping(address user => uint256 shares) public userVaultShares;
    uint256 public userVaultsApproxTotalAssets;
    mapping(IERC4626 vault => bool isWhitelisted) public isUserVaultWhitelisted;
    bool public isUserVaultWhitelistEnabled;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event UserVaultSet(address indexed user, IERC4626 indexed vault);
    event UserVaultWhitelistEnabled(bool indexed previousValue, bool indexed newValue);
    event UserVaultWhitelisted(IERC4626 indexed vault, bool indexed previousValue, bool indexed newValue);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyMarket();

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
        isUserVaultWhitelistEnabled = true;
        isUserVaultWhitelisted[IERC4626(address(0))] = true;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function reinitialize(string memory name_, string memory symbol_) external onlyOwner reinitializer(1_08_00) {
        name = name_;
        symbol = symbol_;

        // v1.8
        isUserVaultWhitelistEnabled = true;
        isUserVaultWhitelisted[IERC4626(address(0))] = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setUserVaultWhitelistEnabled(bool enabled) external onlyOwner {
        emit UserVaultWhitelistEnabled(isUserVaultWhitelistEnabled, enabled);
        isUserVaultWhitelistEnabled = enabled;
    }

    function setUserVaultWhitelisted(IERC4626 vault, bool whitelisted) external onlyOwner {
        emit UserVaultWhitelisted(vault, isUserVaultWhitelisted[vault], whitelisted);
        isUserVaultWhitelisted[vault] = whitelisted;
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfer tokens from one account to another
    /// @param from The account to transfer the tokens from
    /// @param to The account to transfer the tokens to
    /// @param value The unscaled amount of tokens to transfer
    /// @dev Due to rounding, the Transfer event may not represent the actual unscaled amount or the actual number of shares
    /// @return True if the transfer was successful
    function transferFrom(address from, address to, uint256 value) public virtual onlyMarket returns (bool) {
        IERC4626 vaultFrom = userVault[from];
        IERC4626 vaultTo = userVault[to];

        if (vaultFrom == vaultTo) {
            if (address(vaultFrom) != address(0)) {
                _transferFromVaultSame(from, to, value, vaultFrom);
            } else {
                _transferFromAaveSame(from, to, value);
            }
        } else {
            if (address(vaultFrom) != address(0)) {
                _withdrawFromVault(from, address(this), value, vaultFrom);
            } else {
                _withdrawFromAave(from, address(this), value);
            }

            if (address(vaultTo) != address(0)) {
                _depositToVault(address(this), to, value, vaultTo);
            } else {
                _depositToAave(address(this), to, value);
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
    function balanceOf(address account) public view returns (uint256) {
        IERC4626 vault = userVault[account];
        if (address(vault) != address(0)) {
            return vault.convertToAssets(userVaultShares[account]);
        } else {
            return _unscale(scaledBalanceOf[account]);
        }
    }

    /// @inheritdoc IERC20
    /// @notice Returns the approximate total supply of underlying tokens by adding the approximate number of assets in all ERC4626 vaults and the unscaled total supply
    /// @dev This number should be only used for informational purposes
    function totalSupply() public view returns (uint256) {
        return _unscale(scaledTotalSupply) + userVaultsApproxTotalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set the user vault
    /// @param user The user to set the vault for
    /// @param vault The vault to set for the user
    /// @dev This function is only callable by the market
    ///      Setting the vault to `address(0)` will use the default variable pool
    function setUserVault(address user, IERC4626 vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (isUserVaultWhitelistEnabled && !isUserVaultWhitelisted[vault]) {
            revert Errors.USER_VAULT_NOT_WHITELISTED(address(vault));
        }

        emit UserVaultSet(user, vault);
        userVault[user] = vault;
    }

    /// @notice Deposit underlying tokens into the variable pool and mint scaled tokens
    function deposit(address from, address to, uint256 amount) external onlyMarket {
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        IERC4626 vault = userVault[to];
        if (address(vault) != address(0)) {
            _depositToVault(from, to, amount, vault);
        } else {
            _depositToAave(from, to, amount);
        }

        emit Transfer(address(0), to, amount);
    }

    /// @notice Withdraw underlying tokens from the variable pool and burn scaled tokens
    function withdraw(address from, address to, uint256 amount) external onlyMarket {
        IERC4626 vault = userVault[to];
        if (address(vault) != address(0)) {
            _withdrawFromVault(from, to, amount, vault);
        } else {
            _withdrawFromAave(from, to, amount);
        }

        emit Transfer(from, address(0), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the current PPS of the vault, in RAY
    /// @param vault The vault to get the PPS for
    /// @return The current PPS of the vault
    function pps(IERC4626 vault) public view returns (uint256) {
        if (address(vault) != address(0)) {
            return Math.mulDivDown(vault.totalAssets(), WadRayMath.RAY, vault.totalSupply());
        } else {
            return liquidityIndex();
        }
    }

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return aavePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    /*//////////////////////////////////////////////////////////////
                            PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits underlying tokens into a user vault
    /// @param /*from*/ The address to deposit the tokens from
    /// @param to The address to deposit the tokens to
    /// @param amount The amount of tokens to deposit
    /// @param vault The vault to deposit the tokens to
    // slither-disable-next-line reentrancy-benign
    function _depositToVault(address, /*from*/ address to, uint256 amount, IERC4626 vault) private {
        underlyingToken.forceApprove(address(vault), amount);

        uint256 sharesBefore = vault.balanceOf(address(this));

        // slither-disable-next-line unused-return
        vault.deposit(amount, address(this));

        uint256 sharesAfter = vault.balanceOf(address(this));
        uint256 shares = sharesAfter - sharesBefore;

        _mintVault(to, shares, vault.convertToAssets(shares));
    }

    /// @notice Deposits underlying tokens into the Aave pool
    /// @param /*from*/ The address to deposit the tokens from
    /// @param to The address to deposit the tokens to
    /// @param amount The amount of tokens to deposit
    // slither-disable-next-line reentrancy-benign
    function _depositToAave(address, /*from*/ address to, uint256 amount) private {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        underlyingToken.forceApprove(address(aavePool), amount);
        aavePool.supply(address(underlyingToken), amount, address(this), 0);

        uint256 scaledAmount = aToken.scaledBalanceOf(address(this)) - scaledBalanceBefore;

        _mintScaled(to, scaledAmount);
    }

    /// @notice Withdraws underlying tokens from a user vault
    /// @param from The address to withdraw the tokens from
    /// @param to The address to withdraw the tokens to
    /// @param amount The amount of tokens to withdraw
    /// @param vault The vault to withdraw the tokens from
    // slither-disable-next-line reentrancy-benign
    function _withdrawFromVault(address from, address to, uint256 amount, IERC4626 vault) private {
        uint256 sharesBefore = vault.balanceOf(address(this));

        // slither-disable-next-line unused-return
        vault.withdraw(amount, to, address(this));

        uint256 sharesAfter = vault.balanceOf(address(this));
        uint256 shares = sharesBefore - sharesAfter;

        _burnVault(from, shares, vault.convertToAssets(shares));
    }

    /// @notice Withdraws underlying tokens from the Aave pool
    /// @param from The address to withdraw the tokens from
    /// @param to The address to withdraw the tokens to
    /// @param amount The amount of tokens to withdraw
    // slither-disable-next-line reentrancy-benign
    function _withdrawFromAave(address from, address to, uint256 amount) private {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        aavePool.withdraw(address(underlyingToken), amount, to);

        uint256 scaledAmount = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));

        _burnScaled(from, scaledAmount);
    }

    /// @notice Transfers assets between a user vault and another user from the same vault
    /// @dev The assets are converted to shares and then transferred internally
    /// @param from The address to transfer the assets from
    /// @param to The address to transfer the assets to
    /// @param value The amount of assets to transfer
    /// @param vault The vault to transfer the assets from
    function _transferFromVaultSame(address from, address to, uint256 value, IERC4626 vault) private {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        uint256 sharesBefore = vault.convertToShares(value);

        if (userVaultShares[from] < sharesBefore) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        userVaultShares[from] -= sharesBefore;
        userVaultShares[to] += sharesBefore;
    }

    /// @notice Transfers underlying tokens between the Aave pool and a user from the same vault
    /// @dev The underlying tokens are converted to scaled tokens and then transferred internally
    /// @param from The address to transfer the tokens from
    /// @param to The address to transfer the tokens to
    /// @param value The amount of tokens to transfer
    function _transferFromAaveSame(address from, address to, uint256 value) private {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        uint256 scaledAmount = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());

        if (scaledBalanceOf[from] < scaledAmount) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        scaledBalanceOf[from] -= scaledAmount;
        scaledBalanceOf[to] += scaledAmount;
    }

    /// @notice Unscales a scaled amount
    /// @param scaledAmount The scaled amount to unscale
    /// @return The unscaled amount
    /// @dev The unscaled amount is the scaled amount divided by the current liquidity index
    function _unscale(uint256 scaledAmount) private view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Mints NonTransferrableTokenVault tokens based on the number of shares deposited into the user vault
    /// @param to The address to mint the tokens to
    /// @param shares The number of shares to mint
    /// @param assets The number of assets that the shares represent
    function _mintVault(address to, uint256 shares, uint256 assets) private {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        userVaultShares[to] += shares;
        userVaultsApproxTotalAssets += assets;
    }

    /// @notice Mints NonTransferrableTokenVault tokens based on the number of scaled tokens deposited into the Aave pool
    /// @param to The address to mint the tokens to
    /// @param scaledAmount The number of scaled tokens to mint
    function _mintScaled(address to, uint256 scaledAmount) private {
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }

        scaledTotalSupply += scaledAmount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            scaledBalanceOf[to] += scaledAmount;
        }
    }

    /// @notice Burns NonTransferrableTokenVault tokens based on the number of scaled tokens deposited into the Aave pool
    /// @param from The address to burn the tokens from
    /// @param scaledAmount The number of scaled tokens to burn
    function _burnScaled(address from, uint256 scaledAmount) private {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }

        uint256 unscaledAmount = _unscale(scaledAmount);
        if (scaledBalanceOf[from] < scaledAmount) {
            revert ERC20InsufficientBalance(from, balanceOf(from), unscaledAmount);
        }

        scaledBalanceOf[from] -= scaledAmount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            scaledTotalSupply -= scaledAmount;
        }
    }

    /// @notice Burns NonTransferrableTokenVault tokens based on the number of shares and assets
    /// @param from The address to burn the tokens from
    /// @param shares The number of shares to burn
    /// @param assets The number of assets that the shares represent
    function _burnVault(address from, uint256 shares, uint256 assets) private {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }

        userVaultShares[from] -= shares;
        if (userVaultsApproxTotalAssets > assets) {
            userVaultsApproxTotalAssets -= assets;
        } else {
            userVaultsApproxTotalAssets = 0;
        }
    }
}
