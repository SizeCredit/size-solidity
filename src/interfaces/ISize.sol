// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";

import {BorrowerExitParams} from "@src/libraries/actions/BorrowerExit.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/actions/LiquidateLoanWithReplacement.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {SelfLiquidateLoanParams} from "@src/libraries/actions/SelfLiquidateLoan.sol";

import {MoveToVariablePoolParams} from "@src/libraries/actions/MoveToVariablePool.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

interface ISize {
    function deposit(DepositParams memory) external;

    function withdraw(WithdrawParams memory) external;

    // In -> future cash flow -> round up, the borrower needs to pay more
    // Out -> cash, zero risk -> round down, the borrower gets less
    // decreases lender free cash
    // increases borrower free cash
    // if FOL
    //  increases borrower locked eth
    //  increases borrower debtAmount
    // decreases loan offer max amount
    // creates new loans
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external;

    function borrowAsLimitOrder(BorrowAsLimitOrderParams memory params) external;

    // The lender is the one "actively" taking a market order,
    //   so should he be the one penalized with rounding
    // In this case, maybe he should be the one receiving less future cash flow
    //   because he chose to take this offer from the borrower orderbook
    // This means following the logic of penalizing the active part to protect the passive part
    function lendAsMarketOrder(LendAsMarketOrderParams memory params) external;

    function lendAsLimitOrder(LendAsLimitOrderParams memory params) external;

    function borrowerExit(BorrowerExitParams memory params) external;

    // decreases borrower free cash
    // increases protocol free cash
    // increases lender claim(???)
    // decreases borrower locked eth??
    // decreases borrower debtAmount
    // sets loan to repaid
    function repay(RepayParams memory params) external;

    function claim(ClaimParams memory params) external;

    // As soon as a fixed rate loan gets overdue, it should be transformed into a
    //   variable rate one but in reality that might not happen so if it becomes eligible
    //   for liquidation even when overdue then it is good to liquidate that.
    // decreases borrower debtAmount
    // sets loan to repaid
    // etc
    function liquidateLoan(LiquidateLoanParams memory params) external returns (uint256);

    function selfLiquidateLoan(SelfLiquidateLoanParams memory params) external;

    // What is not possible to do for an overdue which is eligible for liquidation is to apply
    //   the replacement because it only makes sense if there is some deltaT to cover between
    //   the liquidation time and the due date time, so for overdue that would be a negative
    //   time and therefore it does not make sense
    function liquidateLoanWithReplacement(LiquidateLoanWithReplacementParams memory params)
        external
        returns (uint256);

    function moveToVariablePool(MoveToVariablePoolParams memory params) external;
}
