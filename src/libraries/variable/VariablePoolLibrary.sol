// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {CollateralLibrary} from "@src/libraries/fixed/CollateralLibrary.sol";

import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";

import {UserLibrary} from "@src/libraries/fixed/UserLibrary.sol";
import {Vault} from "@src/proxy/Vault.sol";

/// @title VariablePoolLibrary
/// @dev Contains functions for interacting with the Variable Pool (Aave v3)
library VariablePoolLibrary {
    using SafeERC20 for IERC20Metadata;
    using CollateralLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using UserLibrary for State;

    /// @notice Deposit underlying borrow tokens into the variable pool
    /// @dev Assumes `from` has approved to `address(this)` the `amount` of underlying borrow tokens
    ///      The deposit is made to the vault of `to`
    /// @param state The state struct
    /// @param from The address of the depositor
    /// @param to The address of the recipient
    /// @param amount The amount of tokens to deposit
    function depositUnderlyingBorrowTokenToVariablePool(State storage state, address from, address to, uint256 amount)
        external
    {
        state.data.underlyingBorrowToken.safeTransferFrom(from, address(this), amount);

        Vault vaultTo = state.getVault(to);

        state.data.underlyingBorrowToken.forceApprove(address(state.data.variablePool), amount);
        state.data.variablePool.supply(address(state.data.underlyingBorrowToken), amount, address(vaultTo), 0);
    }

    /// @notice Withdraw underlying borrow tokens from the variable pool
    /// @dev Assumes `from` has enough aTokens to withdraw
    ///      The withdraw is made from the vault of `from`
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

        Vault vaultFrom = state.getVault(from);

        // slither-disable-next-line unused-return
        vaultFrom.proxy(
            address(state.data.variablePool),
            abi.encodeCall(IPool.withdraw, (address(state.data.underlyingBorrowToken), amount, to))
        );
    }

    /// @notice Transfer aTokens from one user to another, from the vault destined to fixed-rate loans
    /// @dev Assumes `from` has enough aTokens to transfer
    ///      The transfer is made from the vault of `from` to the vault of `to`
    /// @param state The state struct
    /// @param from The address of the sender
    /// @param to The address of the recipient
    /// @param amount The amount of aTokens to transfer
    function transferBorrowAToken(State storage state, address from, address to, uint256 amount) external {
        if (borrowATokenBalanceOf(state, from) < amount) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(from, borrowATokenBalanceOf(state, from), amount);
        }

        Vault vaultFrom = state.getVault(from);
        Vault vaultTo = state.getVault(to);

        // slither-disable-next-line unused-return
        vaultFrom.proxy(address(state.data.borrowAToken), abi.encodeCall(IERC20.transfer, (address(vaultTo), amount)));
    }

    /// @notice Get the balance of borrow aTokens for a user on the Variable Pool
    /// @param state The state struct
    /// @param account The user's address
    /// @return The balance of aTokens
    function borrowATokenBalanceOf(State storage state, address account) public view returns (uint256) {
        return state.data.borrowAToken.balanceOf(address(state.data.users[account].vault));
    }

    /// @notice Get the liquidity index of the Variable Pool (Aave v3)
    /// @param state The state struct
    /// @return The liquidity index
    function borrowATokenLiquidityIndex(State storage state) external view returns (uint256) {
        return state.data.variablePool.getReserveNormalizedIncome(address(state.data.underlyingBorrowToken));
    }
}
