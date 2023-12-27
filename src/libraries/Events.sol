// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

// solhint-disable var-name-mixedcase
library Events {
    event Deposit(address indexed token, uint256 wad);
    event Withdraw(address indexed token, uint256 wad);
    event LendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, YieldCurve curveRelativeTime);
    event BorrowAsLimitOrder(uint256 maxAmount, YieldCurve curveRelativeTime);
    event LendAsMarketOrder(address indexed borrower, uint256 dueDate, uint256 amount, bool exactAmountIn);
    event CreateLoan(
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 exiterId,
        uint256 folId,
        uint256 faceValue,
        uint256 dueDate
    );
    event BorrowAsMarketOrder(
        address indexed borrower,
        address indexed lender,
        uint256 amount,
        uint256 dueDate,
        bool exactAmountIn,
        uint256[] virtualCollateralLoanIds
    );
    event BorrowerExit(uint256 indexed loanId, address lendersToExitTo);
    event LenderExit(uint256 indexed loanId, uint256 amount, uint256 dueDate, address[] lendersToExitTo);
    event Repay(uint256 indexed loanId);
    event Claim(uint256 indexed loanId);
    event LiquidateLoan(uint256 indexed loanId);
    event SelfLiquidateLoan(uint256 indexed loanId);
    event LiquidateLoanWithReplacement(uint256 indexed loanId, address indexed liquidator, address indexed borrower);
}
