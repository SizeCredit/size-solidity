// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/actions/BorrowAsMarketOrder.sol";
import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LenderExitParams} from "@src/libraries/actions/LenderExit.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

interface ISize {
    function deposit(DepositParams memory) external;

    function withdraw(WithdrawParams memory) external;

    // decreases lender free cash
    // increases borrower free cash
    // if FOL
    //  increases borrower locked eth
    //  increases borrower debtAmount
    // decreases loan offer max amount
    // creates new loans
    function borrowAsMarketOrder(BorrowAsMarketOrderParams memory params) external;

    function borrowAsLimitOrder(BorrowAsLimitOrderParams memory params) external;

    function lendAsMarketOrder(LendAsMarketOrderParams memory params) external;

    function lendAsLimitOrder(LendAsLimitOrderParams memory params) external;

    // decreases loanOffer lender free cash
    // increases msg.sender free cash
    // maintains loan borrower accounting
    // decreases loanOffers max amount
    // increases loan amountFVExited
    // creates a new SOL
    function lenderExit(LenderExitParams memory params) external returns (uint256 amountInLeft);

    // decreases borrower free cash
    // increases protocol free cash
    // increases lender claim(???)
    // decreases borrower locked eth??
    // decreases borrower debtAmount
    // sets loan to repaid
    function repay(RepayParams memory params) external;

    function claim(ClaimParams memory params) external;

    function liquidateLoan(LiquidateLoanParams memory params) external returns (uint256);
}
