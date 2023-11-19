// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, LoanOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {PERCENT} from "./libraries/MathLibrary.sol";

import {ISize} from "./interfaces/ISize.sol";

abstract contract SizeVirtualCollateral is SizeStorage, ISize {
    using OfferLibrary for LoanOffer;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function _borrowWithVirtualCollateral(
        uint256 loanOfferId,
        uint256 amount,
        uint256 dueDate,
        uint256[] memory virtualCollateralLoansIds
    ) internal returns (uint256 amountOutLeft) {
        amountOutLeft = amount;

        User storage borrower = users[msg.sender];
        LoanOffer storage loanOffer = loanOffers[loanOfferId];
        uint256 r = PERCENT + loanOffer.getRate(dueDate);

        for (uint256 i = 0; i < virtualCollateralLoansIds.length; ++i) {
            uint256 loanId = virtualCollateralLoansIds[i];
            // Full amount borrowed
            if (amountOutLeft == 0) {
                break;
            }

            Loan storage loan = loans[loanId];
            dueDate = dueDate != type(uint256).max
                ? dueDate
                : loan.getDueDate(loans);

            if (loan.lender != msg.sender) {
                revert ISize.InvalidLoanId(loanId);
            }
            if (dueDate > loanOffer.maxDueDate) {
                // loan is due after loanOffer maxDueDate
                continue;
            }
            if (dueDate < loan.getDueDate(loans)) {
                // loan is due before loanOffer dueDate
                continue;
            }

            uint256 amountInLeft = (r * amountOutLeft) / PERCENT;
            uint256 deltaAmountIn;
            uint256 deltaAmountOut;
            if (amountInLeft >= loan.getCredit()) {
                deltaAmountIn = loan.getCredit();
                deltaAmountOut = (loan.getCredit() * PERCENT) / r;
            } else {
                deltaAmountIn = amountInLeft;
                deltaAmountOut = (amountInLeft * PERCENT) / r;
            }

            loans.createSOL(loanId, loanOffer.lender, msg.sender, deltaAmountIn);
            // NOTE: Transfer deltaAmountOut for each SOL created
            users[loanOffer.lender].cash.transfer(borrower.cash, deltaAmountOut);
            loanOffer.maxAmount -= deltaAmountOut;
            // amountInLeft -= deltaAmountIn;
            amountOutLeft -= deltaAmountOut;
        }
    }
}
