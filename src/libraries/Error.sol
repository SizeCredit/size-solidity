// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";

library Error {
    error USER_IS_LIQUIDATABLE(address account, uint256 cr);
    error NULL_ADDRESS();
    error NULL_AMOUNT();
    error NULL_MAX_DUE_DATE();
    error NULL_ARRAY();
    error ARRAY_LENGTHS_MISMATCH();
    error INVALID_TOKEN(address token);
    error INVALID_COLLATERAL_RATIO(uint256 cr);
    error INVALID_COLLATERAL_PERCENTAGE_PREMIUM(uint256 percentage);
    error INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(uint256 a, uint256 b);
    error INVALID_LIQUIDATION_COLLATERAL_RATIO(uint256 crOpening, uint256 crLiquidation);
    error PAST_DUE_DATE(uint256 dueDate);
    error PAST_MAX_DUE_DATE(uint256 dueDate);
    error DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(uint256 dueDate, uint256 loanDueDate);
    error DUE_DATE_GREATER_THAN_MAX_DUE_DATE(uint256 dueDate, uint256 maxDueDate);
    error INVALID_LENDER(address account);
    error INVALID_LOAN_OFFER(address lender);
    error INVALID_LOAN_STATUS(uint256 loanId, LoanStatus actual, LoanStatus expected);

    error AMOUNT_GREATER_THAN_MAX_AMOUNT(uint256 amount, uint256 maxAmount);
    error AMOUNT_GREATER_THAN_LOAN_CREDIT(uint256 amount, uint256 loanCredit);

    error BORROWER_IS_NOT_LENDER(address borrower, address lender);
    error EXITER_IS_NOT_LENDER(address exiter, address lender);
    error REPAYER_IS_NOT_BORROWER(address repayer, address borrower);
    error CLAIMER_IS_NOT_LENDER(address claimer, address lender);
    error LOAN_ALREADY_CLAIMED(uint256 loanId);

    error NOT_ENOUGH_FREE_CASH(uint256 free, uint256 amount);

    error ONLY_FOL_CAN_BE_REPAID(uint256 loanId);
    error ONLY_FOL_CAN_BE_LIQUIDATED(uint256 loanId);
    error LOAN_ALREADY_REPAID(uint256 loanId);
    error LOAN_NOT_REPAID(uint256 loanId);
    error LOAN_NOT_DUE(uint256 loanId);
    error INVALID_PARTIAL_REPAY_AMOUNT(uint256 amount, uint256 fv);

    error NOT_LIQUIDATABLE(address account);
    error LOAN_NOT_LIQUIDATABLE(uint256 loanId);
    error LIQUIDATION_AT_LOSS(uint256 loanId);
}
