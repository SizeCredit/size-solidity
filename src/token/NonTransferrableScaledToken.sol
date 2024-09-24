// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Math} from "@src/libraries/Math.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title NonTransferrableScaledToken
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
///      Enables the owner to mint and burn scaled amounts.
///      For backward compatibility, emits the TransferUnscaled event representing the actual unscaled amount
contract NonTransferrableScaledToken is Ownable, IERC20Metadata, IERC20Errors {
    IPool private immutable variablePool;
    IERC20Metadata private immutable underlyingToken;

    string public name;
    string public symbol;
    uint8 public immutable decimals;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balanceOf;

    event TransferUnscaled(address indexed from, address indexed to, uint256 value);
    event TransferScaled(address indexed from, address indexed to, uint256 value);

    constructor(
        IPool variablePool_,
        IERC20Metadata underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) Ownable(owner_) {
        if (address(variablePool_) == address(0) || address(underlyingToken_) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        variablePool = variablePool_;
        underlyingToken = underlyingToken_;

        name = name_;
        symbol = symbol_;
        decimals = decimals_;
    }

    /// @notice Mint scaled tokens to an account
    /// @param to The account to mint the tokens to
    /// @param scaledAmount The scaled amount of tokens to mint
    /// @dev Emits a TransferUnscaled event representing the actual unscaled amount
    ///      Re-implements `_mint` logic from solmate's ERC20.sol
    function mintScaled(address to, uint256 scaledAmount) external onlyOwner {
        _totalSupply += scaledAmount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            _balanceOf[to] += scaledAmount;
        }

        uint256 unscaledAmount = _unscale(scaledAmount);
        emit Transfer(address(0), to, unscaledAmount);
        emit TransferUnscaled(address(0), to, unscaledAmount);
        emit TransferScaled(address(0), to, scaledAmount);
    }

    /// @notice Burn scaled tokens from an account
    /// @param from The account to burn the tokens from
    /// @param scaledAmount The scaled amount of tokens to burn
    /// @dev Emits a TransferUnscaled event representing the actual unscaled amount
    ///      Re-implements `_burn` logic from solmate's ERC20.sol
    function burnScaled(address from, uint256 scaledAmount) external onlyOwner {
        uint256 unscaledAmount = _unscale(scaledAmount);
        if (_balanceOf[from] < scaledAmount) {
            revert ERC20InsufficientBalance(from, balanceOf(from), unscaledAmount);
        }

        _balanceOf[from] -= scaledAmount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            _totalSupply -= scaledAmount;
        }

        emit Transfer(from, address(0), unscaledAmount);
        emit TransferUnscaled(from, address(0), unscaledAmount);
        emit TransferScaled(from, address(0), scaledAmount);
    }

    /// @notice Transfer tokens from one account to another
    /// @param from The account to transfer the tokens from
    /// @param to The account to transfer the tokens to
    /// @param value The unscaled amount of tokens to transfer
    /// @dev Emits TransferUnscaled events representing the actual unscaled amount
    ///      Scales the amount by the current liquidity index before transferring scaled tokens
    /// @return True if the transfer was successful
    function transferFrom(address from, address to, uint256 value) public virtual onlyOwner returns (bool) {
        uint256 scaledAmount = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());

        if (_balanceOf[from] < scaledAmount) {
            revert ERC20InsufficientBalance(from, balanceOf(from), value);
        }

        _balanceOf[from] -= scaledAmount;
        _balanceOf[to] += scaledAmount;

        emit Transfer(from, to, value);
        emit TransferUnscaled(from, to, value);
        emit TransferScaled(from, to, scaledAmount);

        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address to, uint256 value) public virtual override onlyOwner returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    /// @inheritdoc IERC20
    function allowance(address, address spender) public view virtual override returns (uint256) {
        return spender == owner() ? type(uint256).max : 0;
    }

    /// @inheritdoc IERC20
    function approve(address, uint256) public virtual override returns (bool) {
        revert Errors.NOT_SUPPORTED();
    }

    /// @notice Returns the scaled balance of an account
    /// @param account The account to get the balance of
    /// @return The scaled balance of the account
    function scaledBalanceOf(address account) public view returns (uint256) {
        return _balanceOf[account];
    }

    /// @notice Unscales a scaled amount
    /// @param scaledAmount The scaled amount to unscale
    /// @return The unscaled amount
    /// @dev The unscaled amount is the scaled amount divided by the current liquidity index
    function _unscale(uint256 scaledAmount) internal view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Returns the unscaled balance of an account
    /// @param account The account to get the balance of
    /// @return The unscaled balance of the account
    function balanceOf(address account) public view returns (uint256) {
        return _unscale(scaledBalanceOf(account));
    }

    /// @notice Returns the scaled total supply of the token
    /// @return The scaled total supply of the token
    function scaledTotalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the unscaled total supply of the token
    /// @return The unscaled total supply of the token
    function totalSupply() public view returns (uint256) {
        return _unscale(scaledTotalSupply());
    }

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return variablePool.getReserveNormalizedIncome(address(underlyingToken));
    }
}
