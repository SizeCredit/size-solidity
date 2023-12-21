// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";

library Errors {
    error USER_IS_LIQUIDATABLE(address account, uint256 cr);
    error NULL_ADDRESS();
    error NULL_AMOUNT();
    error NULL_MAX_DUE_DATE();
    error NULL_ARRAY();
    error ARRAY_LENGTHS_MISMATCH();
    error INVALID_TOKEN(address token);
    error INVALID_COLLATERAL_RATIO(uint256 cr);
    error INVALID_COLLATERAL_PERCENTAGE_PREMIUM(uint256 percentage);
    error INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(uint256 sum);
    error INSUFFICIENT_COLLATERAL(uint256 collateral, uint256 requiredCollateral);
    error INVALID_LIQUIDATION_COLLATERAL_RATIO(uint256 crOpening, uint256 crLiquidation);
    error PAST_DUE_DATE(uint256 dueDate);
    error PAST_MAX_DUE_DATE(uint256 dueDate);
    error DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(uint256 dueDate, uint256 loanDueDate);
    error DUE_DATE_GREATER_THAN_MAX_DUE_DATE(uint256 dueDate, uint256 maxDueDate);
    error DUE_DATE_OUT_OF_RANTE(uint256 dueDate, uint256 minDueDate, uint256 maxDueDate);
    error INVALID_LENDER(address account);
    error INVALID_LOAN_OFFER(address lender);
    error INVALID_BORROW_OFFER(address borrower);
    error INVALID_LOAN_STATUS(uint256 loanId, LoanStatus actual, LoanStatus expected);

    error AMOUNT_GREATER_THAN_MAX_AMOUNT(uint256 amount, uint256 maxAmount);
    error AMOUNT_GREATER_THAN_LOAN_CREDIT(uint256 amount, uint256 loanCredit);

    error BORROWER_IS_NOT_LENDER(address borrower, address lender);
    error LIQUIDATOR_IS_NOT_BORROWER(address liquidator, address borrower);
    error EXITER_IS_NOT_LENDER(address exiter, address lender);
    error EXITER_IS_NOT_BORROWER(address exiter, address borrower);
    error REPAYER_IS_NOT_BORROWER(address repayer, address borrower);
    error CLAIMER_IS_NOT_LENDER(address claimer, address lender);
    error LOAN_ALREADY_CLAIMED(uint256 loanId);

    error NOT_ENOUGH_FREE_CASH(uint256 free, uint256 amount);
    error NOT_ENOUGH_LOCKED_CASH(uint256 locked, uint256 amount);
    error FACE_VALUE_LOWER_THAN_MINIMUM_FACE_VALUE(uint256 faceValue, uint256 minimumFaceValue);

    error ONLY_FOL_CAN_BE_REPAID(uint256 loanId);
    error ONLY_FOL_CAN_BE_EXITED(uint256 loanId);
    error ONLY_FOL_CAN_BE_LIQUIDATED(uint256 loanId);
    error ONLY_FOL_CAN_BE_MOVED_TO_VP(uint256 loanId);
    error LOAN_ALREADY_REPAID(uint256 loanId);
    error LOAN_NOT_REPAID(uint256 loanId);
    error LOAN_NOT_DUE(uint256 loanId);
    error INVALID_PARTIAL_REPAY_AMOUNT(uint256 amount, uint256 fv);

    error NOT_LIQUIDATABLE(address account);
    error LOAN_NOT_LIQUIDATABLE_STATUS(uint256 loanId, LoanStatus status);
    error LOAN_NOT_LIQUIDATABLE_CR(uint256 loanId, uint256 cr);
    error LIQUIDATION_AT_LOSS(uint256 loanId);
    error LIQUIDATION_NOT_AT_LOSS(uint256 loanId);

    error INVALID_DECIMALS(uint8 decimals);
    error INVALID_PRICE(address aggregator, int256 price);
    error STALE_PRICE(address aggregator, uint256 updatedAt);
    error NULL_STALE_PRICE();

    error NOT_SUPPORTED();
}
