// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {PERCENT} from "./libraries/MathLibrary.sol";

import {ISize} from "./interfaces/ISize.sol";
import {SizeView} from "./SizeView.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";

import {BorrowAsMarketOrdersParams} from "@src/SizeBorrowAsMarketOrder.sol";

abstract contract SizeSecurityValidations is SizeView, ISize {
    function _validateUserIsNotLiquidatable(address account) internal view {
        if (isLiquidatable(account)) {
            revert ERROR_USER_IS_LIQUIDATABLE(account);
        }
    }
}

abstract contract SizeInputValidations is SizeView, ISize {
    function _validateNonNull(address account) internal pure {
        if (account == address(0)) {
            revert ERROR_NULL_ADDRESS();
        }
    }

    function _validateCollateralRatio(uint256 cr) internal pure {
        if (cr < PERCENT) {
            revert ERROR_INVALID_COLLATERAL_RATIO(cr);
        }
    }

    function _validateCollateralRatio(uint256 crOpening, uint256 crLiquidation) internal pure {
        if (crOpening <= crLiquidation) {
            revert ERROR_INVALID_LIQUIDATION_COLLATERAL_RATIO(crOpening, crLiquidation);
        }
    }

    function _validateCollateralPercentagePremium(uint256 percentage) internal pure {
        if (percentage > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM(percentage);
        }
    }

    function _validateCollateralPercentagePremium(uint256 a, uint256 b) internal pure {
        if (a + b > PERCENT) {
            revert ERROR_INVALID_COLLATERAL_PERCENTAGE_PREMIUM_SUM(a, b);
        }
    }

    function _validateDueDate(uint256 dueDate) internal view {}
}

abstract contract SizeBorrowAsMarketOrderValidations is SizeView, ISize {
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function _validateBorrowAsMarketOrder(BorrowAsMarketOrdersParams memory params) internal view {
        LoanOffer memory loanOffer = loanOffers[params.loanOfferId];
        address lender = loanOffer.lender;
        User memory lenderUser = users[lender];

        // validate params.borrower
        // N/A

        // validate params.loanOfferId
        if (params.loanOfferId == 0 || params.loanOfferId >= loanOffers.length) {
            revert ERROR_INVALID_LOAN_OFFER_ID(params.loanOfferId);
        }

        // validate params.amount
        if (params.amount > loanOffer.maxAmount) {
            revert ERROR_AMOUNT_GREATER_THAN_MAX_AMOUNT(params.amount, loanOffer.maxAmount);
        }
        if (lenderUser.cash.free < params.amount) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(lenderUser.cash.free, params.amount);
        }

        // validate params.dueDate
        if (params.dueDate < block.timestamp) {
            revert ERROR_PAST_DUE_DATE(params.dueDate);
        }

        // validate params.virtualCollateralLoansIds
        for (uint256 i = 0; i < params.virtualCollateralLoansIds.length; ++i) {
            uint256 loanId = params.virtualCollateralLoansIds[i];
            Loan memory loan = loans[loanId];

            if (loan.lender != params.borrower) {
                revert ERROR_BORROWER_IS_NOT_LENDER(params.borrower, loan.lender);
            }
            if (params.dueDate < loan.getDueDate(loans)) {
                revert ERROR_DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(params.dueDate, loan.getDueDate(loans));
            }
        }
    }
}

abstract contract SizeValidations is
    SizeSecurityValidations,
    SizeInputValidations,
    SizeBorrowAsMarketOrderValidations
{}
