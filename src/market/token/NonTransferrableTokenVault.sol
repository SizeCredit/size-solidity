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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

/// @title NonTransferrableTokenVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol. This vault holds aTokens and ERC4626 tokens on behalf of users and mints 
///         a rebasing ERC20 deposit token to users representing their underlying token amount.
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
///      This contract was upgraded from NonTransferrableScaledTokenV1_5 in v1.8
///      By default, underlying tokens are deposited into the Aave pool, unless the user has set a vault
///      User vaults are untrusted. TODO: do we need to put reentrancy guards everywhere???
contract NonTransferrableTokenVault is IERC20Metadata, IERC20Errors, Ownable2StepUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20Metadata;

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
    mapping(address user => IERC4626 vault) public userVaults;

    event UserVaultSet(address indexed user, IERC4626 indexed vault);

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
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyMarket() {
        if (!sizeFactory.isMarket(msg.sender)) {
            revert Errors.UNAUTHORIZED(msg.sender);
        }
        _;
    }

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

        uint256 unscaledAmount = _unscale(scaledAmount);
        emit Transfer(address(0), to, unscaledAmount);
    }

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

        emit Transfer(from, address(0), unscaledAmount);
    }

    /// @notice Transfer tokens from one account to another
    /// @param from The account to transfer the tokens from
    /// @param to The account to transfer the tokens to
    /// @param value The unscaled amount of tokens to transfer
    /// @dev Emits TransferUnscaled events representing the actual unscaled amount
    ///      Scales the amount by the current liquidity index before transferring scaled tokens
    /// @return True if the transfer was successful
    function transferFrom(address from, address to, uint256 value) public virtual onlyMarket returns (bool) {
        return _transferFromAave(from, to, value);
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 value) public virtual override onlyMarket returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    /// @inheritdoc IERC20
    function allowance(address, address spender) public view virtual override returns (uint256) {
        return sizeFactory.isMarket(spender) ? type(uint256).max : 0;
    }

    /// @inheritdoc IERC20
    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @notice Set the user vault
    /// @param user The user to set the vault for
    /// @param vault The vault to set for the user
    /// @dev This function is only callable by the market
    ///      Setting the vault to `address(0)` will use the default variable pool
    function setUserVault(address user, IERC4626 vault) external onlyMarket {
        if (user == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit UserVaultSet(user, vault);
        userVaults[user] = vault;
    }

    /// @notice Get the user vault
    /// @param user The user to get the vault for
    /// @return The vault for the user
    /// @dev Returns the default vault if the user has no vault set
    function getUserVault(address user) external view returns (IERC4626) {
        return userVaults[user];
    }

    /// @notice Unscales a scaled amount
    /// @param scaledAmount The scaled amount to unscale
    /// @return The unscaled amount
    /// @dev The unscaled amount is the scaled amount divided by the current liquidity index
    function _unscale(uint256 scaledAmount) private view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Returns the unscaled balance of an account
    /// @param account The account to get the balance of
    /// @return The unscaled balance of the account
    function balanceOf(address account) public view returns (uint256) {
        return _unscale(scaledBalanceOf[account]);
    }

    /// @notice Returns the unscaled total supply of the token
    /// @return The unscaled total supply of the token
    function totalSupply() public view returns (uint256) {
        return _unscale(scaledTotalSupply);
    }

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return aavePool.getReserveNormalizedIncome(address(underlyingToken));
    }

    /// @notice Deposit underlying tokens into the variable pool and mint scaled tokens
    // slither-disable-next-line reentrancy-benign
    function deposit(address from, address to, uint256 amount) external onlyMarket {
        _depositToAave(from, to, amount);
    }

    /// @notice Withdraw underlying tokens from the variable pool and burn scaled tokens
    // slither-disable-next-line reentrancy-benign
    function withdraw(address from, address to, uint256 amount) external onlyMarket {
        _withdrawFromAave(from, to, amount);
    }

    function _depositToAave(address, address to, uint256 amount) private {
        underlyingToken.safeTransferFrom(msg.sender, address(this), amount);

        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        underlyingToken.forceApprove(address(aavePool), amount);
        aavePool.supply(address(underlyingToken), amount, address(this), 0);

        uint256 scaledAmount = aToken.scaledBalanceOf(address(this)) - scaledBalanceBefore;

        _mintScaled(to, scaledAmount);
    }

    function _withdrawFromAave(address from, address to, uint256 amount) private {
        IAToken aToken = IAToken(aavePool.getReserveData(address(underlyingToken)).aTokenAddress);

        uint256 scaledBalanceBefore = aToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        aavePool.withdraw(address(underlyingToken), amount, to);

        uint256 scaledAmount = scaledBalanceBefore - aToken.scaledBalanceOf(address(this));

        _burnScaled(from, scaledAmount);
    }

    function _transferFromAave(address from, address to, uint256 value) private returns (bool) {
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

        emit Transfer(from, to, value);

        return true;
    }
}
