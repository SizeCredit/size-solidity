// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {Size} from "@src/Size.sol";

contract SizeAdapter is Size {
// Change Size functions visibility to public for testing
// function ___deposit(address token, uint256 amount) external {
//     deposit(DepositParams({token: token, amount: amount}));
// }

// function ___withdraw(address token, uint256 amount) external {
//     withdraw(WithdrawParams({token: token, amount: amount}));
// }

// function ___borrowAsMarketOrder(
//     address lender,
//     uint256 amount,
//     uint256 dueDate,
//     bool exactAmountIn,
//     uint256[] memory virtualCollateralLoanIds
// ) external {
//     borrowAsMarketOrder(
//         BorrowAsMarketOrderParams({
//             lender: lender,
//             amount: amount,
//             dueDate: dueDate,
//             exactAmountIn: exactAmountIn,
//             virtualCollateralLoanIds: virtualCollateralLoanIds
//         })
//     );
// }

// function ___borrowAsLimitOrder(uint256 maxAmount, uint256[] memory timeBuckets, uint256[] memory rates) external {
//     borrowAsLimitOrder(
//         BorrowAsLimitOrderParams({
//             maxAmount: maxAmount,
//             curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
//         })
//     );
// }

// function ___lendAsMarketOrder(address borrower, uint256 dueDate, uint256 amount, bool exactAmountIn) external {
//     lendAsMarketOrder(
//         LendAsMarketOrderParams({borrower: borrower, dueDate: dueDate, amount: amount, exactAmountIn: exactAmountIn})
//     );
// }

// function ___lendAsLimitOrder(
//     uint256 maxAmount,
//     uint256 maxDueDate,
//     uint256[] memory timeBuckets,
//     uint256[] memory rates
// ) external {
//     lendAsLimitOrder(
//         LendAsLimitOrderParams({
//             maxAmount: maxAmount,
//             maxDueDate: maxDueDate,
//             curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
//         })
//     );
// }

// function ___borrowerExit(uint256 loanId, address borrowerToExitTo) external {
//     borrowerExit(BorrowerExitParams({loanId: loanId, borrowerToExitTo: borrowerToExitTo}));
// }

// function ___repay(uint256 loanId) external {
//     repay(RepayParams({loanId: loanId}));
// }

// function ___claim(uint256 loanId) external {
//     claim(ClaimParams({loanId: loanId}));
// }

// function ___liquidateLoan(uint256 loanId) external returns (uint256) {
//     return liquidateLoan(LiquidateLoanParams({loanId: loanId}));
// }

// function ___selfLiquidateLoan(uint256 loanId) external {
//     selfLiquidateLoan(SelfLiquidateLoanParams({loanId: loanId}));
// }

// function ___liquidateLoanWithReplacement(uint256 loanId, address borrower) external returns (uint256) {
//     return liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams({loanId: loanId, borrower: borrower}));
// }

// function ___moveToVariablePool(uint256 loanId) external {
//     moveToVariablePool(MoveToVariablePoolParams({loanId: loanId}));
// }
}
