// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/fixed/actions/Claim.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/fixed/actions/LiquidateLoan.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/fixed/actions/SelfLiquidateLoan.sol";

import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {LiquidateVariableParams} from "@src/libraries/variable/actions/LiquidateVariable.sol";
import {RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";

/// @title ISize
/// @author Size Lending
/// @notice This interface is the main interface for all user-facing methods of the Size v2 protocol
interface ISize {
    /// @notice Deposit underlying borrow/collateral tokens to the protocol (e.g. USDC, WETH)
    ///         Borrow tokens are always deposited into the Variable Pool,
    ///         wheteher `variable` is passed as `true` or `false`. The difference is that a `true`
    ///         value means this deposit is destined for variable-rate lending only, while a `false` value
    ///         means this deposit is destined for both fixed-rate lending and variable-rate lending.
    ///         Collateral tokens are deposited into the Variable Pool only if the user passes
    ///         `variable` as `true`. If `variable` is `false`, the collateral tokens are deposited
    ///         into the Size contract through the CollateralLibrary.
    /// @dev The caller must approve the transfer of the token to the protocol.
    ///      This function mints 1:1 szTokens (e.g. aszUSDC, szETH) in exchange of the deposited tokens
    /// @param params DepositParams struct containing the following fields:
    ///     - address token: The address of the token to deposit
    ///     - uint256 amount: The amount of tokens to deposit
    ///     - uint256 to: The recipient of the deposit
    ///     - bool variable: Whether the deposit is destined for variable-rate lending or fixed-rate lending
    function deposit(DepositParams calldata params) external;

    /// @notice Withdraw underlying borrow/collateral tokens from the protocol (e.g. USDC, WETH)
    ///         Borrow tokens are always withdrawn into the Variable Pool,
    ///         wheteher `variable` is passed as `true` or `false`. The difference is that a `true`
    ///         value means the withdrawal is taken from variable-rate lending, while a `false` value
    ///         means the withdrawal is taken for both fixed-rate lending and variable-rate lending.
    ///         Collateral tokens are withdrawn from the Variable Pool only if the user passes
    ///         `variable` as `true`. If `variable` is `false`, the collateral tokens are withdrawn
    ///         from the Size contract through the CollateralLibrary.
    /// @dev This function burns 1:1 szTokens (e.g. aszUSDC, szETH) in exchange of the withdrawn tokens
    /// @param params WithdrawParams struct containing the following fields:
    ///     - address token: The address of the token to withdraw
    ///     - uint256 amount: The amount of tokens to withdraw (in decimals, e.g. 1_000e6 for 1000 USDC or 10e18 for 10 WETH)
    ///     - uint256 to: The recipient of the withdrawal
    ///     - bool variable: Whether the deposit is destined for variable-rate lending or fixed-rate lending
    function withdraw(WithdrawParams calldata params) external;

    /// @notice Picks a lender offer and borrow tokens from the orderbook
    ///         When using receivable loans as credit, the early exit lender fee is applied to the borrower
    /// @dev The `amount` parameter is altered by the function, which is why the `params` argument is marked as `memory`
    ///      Order "takers" are the ones who pay the rounding, since "makers" are the ones passively waiting for an order to be matched
    /// @param params BorrowAsMarketOrderParams struct containing the following fields:
    ///     - address lender: The address of the lender
    ///     - uint256 amount: The amount of tokens to borrow (in decimals, e.g. 1_000e6 for 1000 aszUSDC)
    ///     - uint256 dueDate: The due date of the loan
    ///     - bool exactAmountIn: When passing an array of receivable loans, this flag indicates if the amount is value to be returned at due date
    ///     - uint256[] receivableLoanIds: The ids of receivable loans that can be used as credit to borrow without assigining new collateral
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external;

    /// @notice Places a new borrow offer in the orderbook
    /// @param params BorrowAsLimitOrderParams struct containing the following fields:
    ///     - uint256 openingLimitBorrowCR: The opening limit borrow collateral ratio, which indicates the maximum CR the borrower is willing to accept after their offer is picked by a lender
    ///     - YieldCurve curveRelativeTime: The yield curve for the borrow offer, a struct containing the following fields:
    ///         - uint256[] timeBuckets: The relative timestamps of the yield curve (for example, [30 days, 60 days, 90 days])
    ///         - uint256[] rates: The rates of the yield curve (for example, [0.05e18, 0.07e18, 0.08e18] to represent 5%, 7%, and 8% respectively)
    ///         - int256[] marketRateMultipliers: The market rate multipliers of the yield curve (for example, [0.99e18, 1e18, 1.1e18] to represent 99%, 100%, and 110% of the market borrow rate, respectively)
    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) external;

    /// @notice Places a new lend offer in the orderbook
    /// @param params LendAsMarketOrderParams struct containing the following fields:
    ///     - address borrower: The address of the borrower
    ///     - uint256 amount: The amount of tokens to lend (in decimals, e.g. 1_000e6 for 1000 aszUSDC)
    ///     - uint256 dueDate: The due date of the loan
    ///     - bool exactAmountIn: This flag indicates if the amount is the value to be transferred to the borrower or if it should be used to calculate the amount to be transferred
    function lendAsMarketOrder(LendAsMarketOrderParams calldata params) external;

    /// @notice Places a new lend offer in the orderbook
    /// @param params LendAsLimitOrderParams struct containing the following fields:
    ///     - uint256 maxDueDate: The maximum timestamp the limit order can be picked by a borrower (e.g., 1712188800 for April 4th, 2024)
    ///     - YieldCurve curveRelativeTime: The yield curve for the lend offer, a struct containing the following fields:
    ///         - uint256[] timeBuckets: The relative timestamps of the yield curve (for example, [30 days, 60 days, 90 days])
    ///         - uint256[] rates: The rates of the yield curve (for example, [0.05e18, 0.07e18, 0.08e18] to represent 5%, 7%, and 8% respectively)
    ///         - int256[] marketRateMultipliers: The market rate multipliers of the yield curve (for example, [1e18, 1.2e18, 1.3e18] to represent 100%, 120%, and 130% of the market borrow rate, respectively)
    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) external;

    /// @notice Exits a loan to a new borrower by picking the new borrower offer from the orderbook
    ///         When exiting a loan to a new borrower, the early exit borrower fee is applied to the current borrower
    /// @dev The current borrower debt is transferred to the new borrower, together with the borrow tokens according to the new borrower yield curve
    /// @param params BorrowerExitParams struct containing the following fields:
    ///     - uint256 loanId: The id of the loan to exit
    ///     - address borrowerToExitTo: The address of the borrower to exit to
    function borrowerExit(BorrowerExitParams calldata params) external;

    /// @notice Repay a loan by transferring the amount due of borrow tokens to the protocol, which are deposited to the Variable Pool for the lenders to claim
    ///         Partial repayment are currently unsupported
    ///         The protocol repay fee is applied upon repayment
    /// @dev The Variable Pool liquidity index is snapshotted at the time of the repayment in order to calculate the accrued interest for lenders to claim
    /// @param params RepayParams struct containing the following fields:
    ///     - uint256 loanId: The id of the loan to repay
    function repay(RepayParams calldata params) external;

    /// @notice Claim the repayment of a loan with accrued interest from the Variable Pool
    /// @dev Both ACTIVE and OVERDUE loans can't be claimed because the money is not in the protocol yet.
    ///      CLAIMED loans can't be claimed either because its credit has already been consumed entirely either by a previous claim or by exiting before
    /// @param params ClaimParams struct containing the following fields:
    ///     - uint256 loanId: The id of the loan to claim
    function claim(ClaimParams calldata params) external;

    /// @notice Liquidate a loan
    ///         In case of protifable liquiadtion, part of the collateral remainder is split between the protocol and the liquidator
    ///         The protocol repayment fee is charged from the borrower
    ///         If the loan is overdue, a move transfer fee is charged from the borrower
    ///
    ///         The liquidation logic contains the following specification:
    ///             if 100% <= CR < CRL:
    ///                 liquidate loan and split the collateral remainder
    ///             else if 0% <= CR < 100%:
    ///                 liquidate unprofitably depending on minCR parameter
    ///             else: // CR >= CRL
    ///                 if loan is overdue:
    ///                     if loan can be moved to the variable pool:
    ///                         move loan to the variable pool, charge move transfer fee in collateral from the borrower
    ///                     else:
    ///                         liquidate loan, do not split the collateral remainder, charge move transfer fee in collateral from the borrower
    ///                 else:
    ///                     loan cannot be liquidated
    /// @param params LiquidateLoanParams struct containing the following fields:
    ///     - uint256 loanId: The id of the loan to liquidate
    ///     - uint256 minimumCollateralProfit: The minimum collateral profit that the liquidator is willing to accept from the borrower (keepers might choose to pass a value below 100% of the cash they bring and take the risk of liquidating unprofitably)
    function liquidateLoan(LiquidateLoanParams calldata params) external returns (uint256);

    /// @notice Self liquidate a loan that is undercollateralized
    ///         The lender cancels an amount of debt equivalent to their credit and a percentage of the protocol fees
    /// @param params SelfLiquidateLoanParams struct containing the following fields:
    ///     - uint256 loanId: The id of the loan to self-liquidate
    function selfLiquidateLoan(SelfLiquidateLoanParams calldata params) external;

    /// @notice Liquidate a loan with a replacement borrower
    /// @dev This function works exactly like `liquidateLoan`, with an added logic of replacing the borrower on the storage
    ///         When liquidating with replacement, nothing changes from the lender's perspective, but a spread is created between the previous borrower rate and the new borrower rate.
    ///         As a result of the spread of these borrow rates, the protocol is able to profit from the liquidation. Since the choice of the borrower impacts on the protocol's profit, this method is permissioned
    /// @param params LiquidateLoanWithReplacementParams struct containing the following fields:
    ///     - uint256 loanId: The id of the loan to liquidate
    ///     - uint256 minimumCollateralProfit: The minimum collateral profit that the liquidator is willing to accept from the borrower (keepers might choose to pass a value below 100% of the cash they bring and take the risk of liquidating unprofitably)
    ///     - address borrower: The address of the replacement borrower
    function liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams calldata params)
        external
        returns (uint256, uint256);

    /// @notice Compensate a borrower's debt with his credit in another loan
    ///         The compensation can not exceed both 1) the credit the lender of `loanToRepayId` to the borrower and 2) the credit the lender of `loanToCompensateId`
    /// @param params CompensateParams struct containing the following fields:
    ///     - uint256 loanToRepayId: The id of the loan to repay
    ///     - uint256 loanToCompensateId: The id of the loan to compensate
    ///     - uint256 amount: The amount of tokens to compensate (in decimals, e.g. 1_000e6 for 1000 aszUSDC)
    function compensate(CompensateParams calldata params) external;

    /// @notice Check if an account is allowlisted to interact with the Variable Pool
    /// @dev Only vaults should be allowlisted. See `UserLibrary`
    /// @param account The address of the account to check
    /// @return Whether the account is allowlisted
    function variablePoolAllowlisted(address account) external returns (bool);

    /// @notice Borrow a variable loan by forwarding a call from the user proxy to the Variable Pool `borrow`
    /// @param params BorrowVariableParams struct containing the following fields:
    ///     - address to: The recipient address
    ///     - uint256 amount: The amount to borrow
    function borrowVariable(BorrowVariableParams calldata params) external;

    /// @notice Repay a variable loan by forwarding a call from the user proxy to the Variable Pool `repayWithATokens`
    /// @param params RepayVariableParams struct containing the following fields:
    ///     - uint256 amount: The amount to repay
    function repayVariable(RepayVariableParams calldata params) external;

    /// @notice Liquidate a variable loan by forwarding a call from the user proxy to the Variable Pool `liquidationCall`
    /// @param params RepayVariableParams struct containing the following fields:
    ///     - address borrower: The liquidated address
    ///     - uint256 amount: The debt amount to cover
    function liquidateVariable(LiquidateVariableParams calldata params) external;
}
