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

abstract contract SizeRealCollateral is SizeStorage, ISize {
    using OfferLibrary for LoanOffer;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function _borrowWithRealCollateral(
        uint256 loanOfferId,
        uint256 amountOutLeft,
        uint256 dueDate
    ) internal {
        User storage borrower = users[msg.sender];
        LoanOffer storage loanOffer = loanOffers[loanOfferId];
        uint256 r = PERCENT + loanOffer.getRate(dueDate);

        uint256 FV = (r * amountOutLeft) / PERCENT;
        uint256 maxETHToLock = ((FV * CROpening) / priceFeed.getPrice());
        borrower.eth.lock(maxETHToLock);
        borrower.totDebtCoveredByRealCollateral += FV;
        loans.createFOL(loanOffer.lender, msg.sender, FV, dueDate);
        users[loanOffer.lender].cash.transfer(borrower.cash, amountOutLeft);
        loanOffer.maxAmount -= amountOutLeft;
    }
}
