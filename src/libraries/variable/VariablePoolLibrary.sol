// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title VariablePoolLibrary
/// @dev Contains functions for interacting with the Variable Pool (Aave v3)
library VariablePoolLibrary {
    using SafeERC20 for IERC20Metadata;

    /// @notice Deposit underlying borrow tokens into the variable pool
    /// @dev Assumes `from` has approved to `address(this)` the `amount` of underlying borrow tokens
    /// @param state The state struct
    /// @param from The address of the depositor
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to deposit
    function depositUnderlyingBorrowTokenToVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        state.data.underlyingBorrowToken.safeTransferFrom(from, address(this), amount);

        uint256 scaledBalanceBefore = state.data.borrowAToken.scaledBalanceOf(address(this));

        state.data.underlyingBorrowToken.forceApprove(address(state.data.variablePool), amount);
        state.data.variablePool.supply(address(state.data.underlyingBorrowToken), amount, address(this), 0);

        uint256 scaledAmount = state.data.borrowAToken.scaledBalanceOf(address(this)) - scaledBalanceBefore;

        state.data.users[to].scaledBorrowATokenBalance += scaledAmount;
    }

    /// @notice Withdraw underlying borrow tokens from the variable pool
    /// @param state The state struct
    /// @param from The address of the withdrawer
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to withdraw
    function withdrawUnderlyingTokenFromVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        if (borrowATokenBalanceOf(state, from) < amount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(from, borrowATokenBalanceOf(state, from), amount);
        }

        uint256 scaledBalanceBefore = state.data.borrowAToken.scaledBalanceOf(address(this));

        // slither-disable-next-line unused-return
        state.data.variablePool.withdraw(address(state.data.underlyingBorrowToken), amount, to);

        uint256 scaledAmount = scaledBalanceBefore - state.data.borrowAToken.scaledBalanceOf(address(this));

        state.data.users[from].scaledBorrowATokenBalance -= scaledAmount;
    }

    /// @notice Transfer aTokens from one user to another
    /// @param state The state struct
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of aTokens to transfer
    function transferBorrowAToken(State storage state, address from, address to, uint256 amount) external {
        uint256 scaledAmount = WadRayMath.rayDiv(amount, borrowATokenLiquidityIndex(state));

        if (state.data.users[from].scaledBorrowATokenBalance < scaledAmount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(from, borrowATokenBalanceOf(state, from), amount);
        }

        state.data.users[from].scaledBorrowATokenBalance -= scaledAmount;
        state.data.users[to].scaledBorrowATokenBalance += scaledAmount;
    }

    /// @notice Get the balance of borrow aTokens for a user on the Variable Pool
    /// @param state The state struct
    /// @param account The user's address
    /// @return The balance of aTokens
    function borrowATokenBalanceOf(State storage state, address account) public view returns (uint256) {
        return WadRayMath.rayMul(state.data.users[account].scaledBorrowATokenBalance, borrowATokenLiquidityIndex(state));
    }

    /// @notice Get the liquidity index of the Variable Pool (Aave v3)
    /// @param state The state struct
    /// @return The liquidity index
    function borrowATokenLiquidityIndex(State storage state) public view returns (uint256) {
        return state.data.variablePool.getReserveNormalizedIncome(address(state.data.underlyingBorrowToken));
    }
}
