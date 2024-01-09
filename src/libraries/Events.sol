// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

// solhint-disable var-name-mixedcase
library Events {
    event Deposit(address indexed token, uint256 wad);
    event Withdraw(address indexed token, uint256 wad);
    event BorrowAsMarketOrder(
        address indexed lender, uint256 amount, uint256 dueDate, bool exactAmountIn, uint256[] virtualCollateralLoanIds
    );
    event BorrowAsLimitOrder(uint256 maxAmount, YieldCurve curveRelativeTime);
    event LendAsMarketOrder(address indexed borrower, uint256 dueDate, uint256 amount, bool exactAmountIn);
    event LendAsLimitOrder(uint256 maxAmount, uint256 maxDueDate, YieldCurve curveRelativeTime);
    event CreateLoan(
        uint256 indexed loanId,
        address indexed lender,
        address indexed borrower,
        uint256 exiterId,
        uint256 folId,
        uint256 faceValue,
        uint256 dueDate
    );
    event BorrowerExit(uint256 indexed loanId, address borrowerExitedTo);
    event Repay(uint256 indexed loanId, uint256 amount);
    event Claim(uint256 indexed loanId);
    event LiquidateLoan(
        uint256 indexed loanId,
        uint256 minimumCollateralRatio,
        uint256 assignedCollateral,
        uint256 debtInCollateralToken
    );
    event SelfLiquidateLoan(uint256 indexed loanId);
    event LiquidateLoanWithReplacement(
        uint256 indexed loanId, address indexed borrower, uint256 minimumCollateralRatio
    );
    event MoveToVariablePool(uint256 indexed loanId);
    event Compensate(uint256 indexed loanToRepayId, uint256 indexed loanToCompensateId, uint256 amount);
}
