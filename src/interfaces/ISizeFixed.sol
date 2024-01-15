// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateFixedLoanParams} from "@src/libraries/actions/LiquidateFixedLoan.sol";

import {LiquidateFixedLoanWithReplacementParams} from "@src/libraries/actions/LiquidateFixedLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateFixedLoanParams} from "@src/libraries/actions/SelfLiquidateFixedLoan.sol";

import {CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

interface ISizeFixed {
    function deposit(DepositParams calldata) external;

    function withdraw(WithdrawParams calldata) external;

    // In -> future cash flow -> round up, the borrower needs to pay more
    // Out -> cash, zero risk -> round down, the borrower gets less
    // decreases lender free cash
    // increases borrower free cash
    // if FOL
    //  increases borrower locked eth
    //  increases borrower debtAmount
    // decreases loan offer max amount
    // creates new loans
    // NOTE: the `amount` parameter is altered by the function
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external;

    function borrowAsLimitOrder(BorrowAsLimitOrderParams calldata params) external;

    // The lender is the one "actively" taking a market order,
    //   so should he be the one penalized with rounding
    // In this case, maybe he should be the one receiving less future cash flow
    //   because he chose to take this offer from the borrower orderbook
    // This means following the logic of penalizing the active part to protect the passive part
    function lendAsMarketOrder(LendAsMarketOrderParams calldata params) external;

    function lendAsLimitOrder(LendAsLimitOrderParams calldata params) external;

    function borrowerExit(BorrowerExitParams calldata params) external;

    // decreases borrower free cash
    // increases protocol free cash
    // increases lender claim(???)
    // decreases borrower locked eth??
    // decreases borrower debtAmount
    // sets loan to repaid
    function repay(RepayParams calldata params) external;

    // Both ACTIVE and OVERDUE loans can't be claimed because the money is not in the protocol yet
    // The CLAIMED can't be claimed either because its credit has already been consumed entirely
    //    either by a previous claim or by exiting before
    function claim(ClaimParams calldata params) external;

    // As soon as a fixed rate loan gets overdue, it should be transformed into a
    //   variable rate one but in reality that might not happen so if it becomes eligible
    //   for liquidation even when overdue then it is good to liquidate that.
    // decreases borrower debtAmount
    // sets loan to repaid
    // etc
    function liquidateFixedLoan(LiquidateFixedLoanParams calldata params) external returns (uint256);

    function selfLiquidateFixedLoan(SelfLiquidateFixedLoanParams calldata params) external;

    // What is not possible to do for an overdue which is eligible for liquidation is to apply
    //   the replacement because it only makes sense if there is some deltaT to cover between
    //   the liquidation time and the due date time, so for overdue that would be a negative
    //   time and therefore it does not make sense
    function liquidateFixedLoanWithReplacement(LiquidateFixedLoanWithReplacementParams calldata params)
        external
        returns (uint256, uint256);

    function moveToVariablePool(MoveToVariablePoolParams calldata params) external;

    // The borrower compensate his debt in `loanToRepayId` with his credit in `loanToCompensateId`
    // The compensation can not exceed both 1) the credit the lender of `loanToRepayId` to the borrower and 2) the credit the lender of `loanToCompensateId` there
    function compensate(CompensateParams calldata params) external;
}
