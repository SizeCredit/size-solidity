// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, LoanOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {SizeView} from "./SizeView.sol";
import {PERCENT} from "./libraries/MathLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "./interfaces/ISize.sol";

struct BorrowAsMarketOrdersParams {
    address borrower;
    address lender;
    uint256 amount;
    uint256 dueDate;
    uint256[] virtualCollateralLoansIds;
}

abstract contract SizeBorrowAsMarketOrder is SizeStorage, SizeView, ISize {
    using OfferLibrary for LoanOffer;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function _validateBorrowAsMarketOrder(BorrowAsMarketOrdersParams memory params) internal view {
        LoanOffer memory loanOffer = loanOffers[params.lender];
        User memory lenderUser = users[params.lender];

        // validate params.borrower
        // N/A

        // validate params.lender
        if (loanOffer.isNull()) {
            revert ERROR_INVALID_LOAN_OFFER(params.lender);
        }

        // validate params.amount
        if (params.amount == 0) {
            revert ERROR_NULL_AMOUNT();
        }
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
        if (params.dueDate > loanOffer.maxDueDate) {
            revert ERROR_DUE_DATE_GREATER_THAN_MAX_DUE_DATE(params.dueDate, loanOffer.maxDueDate);
        }

        // validate params.virtualCollateralLoansIds
        for (uint256 i = 0; i < params.virtualCollateralLoansIds.length; ++i) {
            uint256 loanId = params.virtualCollateralLoansIds[i];
            Loan memory loan = loans[loanId];

            if (params.borrower != loan.lender) {
                revert ERROR_BORROWER_IS_NOT_LENDER(params.borrower, loan.lender);
            }
            if (params.dueDate < loan.getDueDate(loans)) {
                revert ERROR_DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(params.dueDate, loan.getDueDate(loans));
            }
        }
    }

    /**
     * @notice Borrow with real collateral, an internal state-modifying function.
     * @dev Cover the remaining amount with real collateral
     */
    function _borrowWithRealCollateral(BorrowAsMarketOrdersParams memory params) internal {
        if (params.amount == 0) {
            return;
        }

        User storage borrowerUser = users[params.borrower];
        User storage lenderUser = users[params.lender];
        LoanOffer storage loanOffer = loanOffers[params.lender];
        uint256 r = PERCENT + loanOffer.getRate(params.dueDate);

        uint256 FV = FixedPointMathLib.mulDivUp(r, params.amount, PERCENT);
        uint256 maxETHToLock = FixedPointMathLib.mulDivUp(FV, CROpening, priceFeed.getPrice());
        borrowerUser.eth.lock(maxETHToLock);
        borrowerUser.totDebtCoveredByRealCollateral += FV;
        loans.createFOL(params.lender, params.borrower, FV, params.dueDate);
        lenderUser.cash.transfer(borrowerUser.cash, params.amount);
        loanOffer.maxAmount -= params.amount;
    }

    /**
     * @notice Borrow with virtual collateral, an internal state-modifying function.
     * @dev The `amount` is initialized to `amountOutLeft`, which is decreased as more and more SOLs are created
     */
    function _borrowWithVirtualCollateral(BorrowAsMarketOrdersParams memory params)
        internal
        returns (uint256 amountOutLeft)
    {
        amountOutLeft = params.amount;

        //  amountIn: Amount of future cashflow to exit
        //  amountOut: Amount of cash to borrow at present time

        LoanOffer storage loanOffer = loanOffers[params.lender];
        User storage borrowerUser = users[params.borrower];
        User storage lenderUser = users[params.lender];
        uint256 r = PERCENT + loanOffer.getRate(params.dueDate);

        for (uint256 i = 0; i < params.virtualCollateralLoansIds.length; ++i) {
            // Full amount borrowed
            if (amountOutLeft == 0) {
                break;
            }

            uint256 loanId = params.virtualCollateralLoansIds[i];
            Loan memory loan = loans[loanId];

            uint256 deltaAmountIn;
            uint256 deltaAmountOut;
            if (FixedPointMathLib.mulDivUp(r, amountOutLeft, PERCENT) > loan.getCredit()) {
                deltaAmountIn = loan.getCredit();
                deltaAmountOut = FixedPointMathLib.mulDivUp(loan.getCredit(), PERCENT, r);
            } else {
                deltaAmountIn = FixedPointMathLib.mulDivUp(r, amountOutLeft, PERCENT);
                deltaAmountOut = amountOutLeft;
            }

            loans.createSOL(loanId, params.lender, params.borrower, deltaAmountIn);
            // NOTE: Transfer deltaAmountOut for each SOL created
            lenderUser.cash.transfer(borrowerUser.cash, deltaAmountOut);
            loanOffer.maxAmount -= deltaAmountOut;
            amountOutLeft -= deltaAmountOut;
        }
    }
}
