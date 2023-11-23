// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, LoanOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan, LoanStatus} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {PERCENT} from "./libraries/MathLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "./interfaces/ISize.sol";

struct ExitParams {
    address exiter;
    uint256 loanId;
    uint256 amount;
    uint256 dueDate;
    address[] lendersToExitTo;
}

abstract contract SizeExit is SizeStorage, ISize {
    using OfferLibrary for LoanOffer;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function _validateExit(ExitParams memory params) internal view {
        Loan storage loan = loans[params.loanId];
        // validate exiter
        if (loan.lender != params.exiter) {
            revert ERROR_EXITER_IS_NOT_LENDER(params.exiter, loan.lender);
        }

        // validate loanId
        if (loan.getLoanStatus(loans) != LoanStatus.ACTIVE) {
            revert ERROR_INVALID_LOAN_STATUS(params.loanId, loan.getLoanStatus(loans), LoanStatus.ACTIVE);
        }

        // validate amount
        if (params.amount == 0) {
            revert ERROR_NULL_AMOUNT();
        }
        if (params.amount > loan.getCredit()) {
            revert ERROR_AMOUNT_GREATER_THAN_LOAN_CREDIT(params.amount, loan.getCredit());
        }

        // validate dueDate
        // TODO

        // validate lendersToExitTo
        for (uint256 i; i < params.lendersToExitTo.length; ++i) {
            address lender = params.lendersToExitTo[i];
            if (lender == address(0)) {
                revert ERROR_NULL_ADDRESS();
            }
            // @audit should we prevent exit to self?
            // if (lender == params.exiter) {
            //     revert ERROR_INVALID_LENDER(lender);
            // }
            if (users[lender].loanOffer.isNull()) {
                revert ERROR_INVALID_LOAN_OFFER(lender);
            }
        }
    }

    // NOTE: The exit is equivalent to a spot swap for exact amount in wheres
    // - the exiting lender is the taker
    // - the other lenders are the makers
    // The swap traverses the `loanOfferIds` as they if they were ticks with liquidity in an orderbook
    function _exit(ExitParams memory params) internal returns (uint256 amountInLeft) {
        User storage exiterUser = users[params.exiter];
        amountInLeft = params.amount;
        for (uint256 i = 0; i < params.lendersToExitTo.length; ++i) {
            if (amountInLeft == 0) {
                // No more amountIn to swap
                break;
            }

            address lender = params.lendersToExitTo[i];
            User storage lenderUser = users[lender];
            LoanOffer storage loanOffer = lenderUser.loanOffer;
            uint256 r = PERCENT + loanOffer.getRate(params.dueDate);
            uint256 deltaAmountIn;
            uint256 deltaAmountOut;
            // @audit check rounding direction
            if (amountInLeft > loanOffer.maxAmount) {
                deltaAmountIn = FixedPointMathLib.mulDivUp(r, loanOffer.maxAmount, PERCENT);
                deltaAmountOut = loanOffer.maxAmount;
            } else {
                deltaAmountIn = amountInLeft;
                deltaAmountOut = FixedPointMathLib.mulDivUp(deltaAmountIn, PERCENT, r);
            }

            loans.createSOL(params.loanId, lender, params.exiter, deltaAmountIn);
            lenderUser.cash.transfer(exiterUser.cash, deltaAmountOut);
            loanOffer.maxAmount -= deltaAmountOut;
            amountInLeft -= deltaAmountIn;
            // @audit update LOAN
        }
    }
}
