// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface ISizeErrors {
    error ERROR_USER_IS_LIQUIDATABLE(address account);
    error ERROR_NULL_ADDRESS();
    error ERROR_NULL_AMOUNT();
    error ERROR_INVALID_COLLATERAL_RATIO(uint256 cr);
    error ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM(uint256 percentage);
    error ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(uint256 a, uint256 b);
    error ERROR_INVALID_LIQUIDATION_COLLATERAL_RATIO(uint256 crOpening, uint256 crLiquidation);
    error ERROR_PAST_DUE_DATE(uint256 dueDate);
    error ERROR_DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(uint256 dueDate, uint256 loanDueDate);
    error ERROR_INVALID_LENDER(address account);
    error ERROR_INVALID_LOAN_OFFER_ID(uint256 loanOfferId);

    error ERROR_AMOUNT_GREATER_THAN_MAX_AMOUNT(uint256 amount, uint256 maxAmount);
    error ERROR_AMOUNT_GREATER_THAN_LOAN_CREDIT(uint256 amount, uint256 loanCredit);

    error ERROR_BORROWER_IS_NOT_LENDER(address borrower, address lender);
    error ERROR_EXITER_IS_NOT_LENDER(address exiter, address lender);

    error ERROR_NOT_ENOUGH_FREE_CASH(uint256 free, uint256 amount);

    error ERROR_ONLY_FOL_CAN_BE_REPAID(uint256 loanId);
    error ERROR_LOAN_ALREADY_REPAID(uint256 loanId);
    error ERROR_INVALID_PARTIAL_REPAY_AMOUNT(uint256 amount, uint256 fv);

    error ERROR_NOT_LIQUIDATABLE(address account);
}
