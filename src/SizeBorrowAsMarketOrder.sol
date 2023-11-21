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

struct BorrowAsMarketOrdersParams {
    address borrower;
    uint256 loanOfferId;
    uint256 amount;
    uint256 dueDate;
    uint256[] virtualCollateralLoansIds;
}

abstract contract SizeBorrowAsMarketOrder is SizeStorage, ISize {
    using OfferLibrary for LoanOffer;
    using RealCollateralLibrary for RealCollateral;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    /**
     * @notice Borrow with real collateral, an internal state-modifying function.
     * @dev Cover the remaining amount with real collateral
     */
    function _borrowWithRealCollateral(BorrowAsMarketOrdersParams memory params) internal {
        if (params.amount == 0) {
            return;
        }

        User storage borrowerUser = users[params.borrower];
        LoanOffer storage loanOffer = loanOffers[params.loanOfferId];
        uint256 r = PERCENT + loanOffer.getRate(params.dueDate);

        uint256 FV = (r * params.amount) / PERCENT;
        uint256 maxETHToLock = ((FV * CROpening) / priceFeed.getPrice());
        borrowerUser.eth.lock(maxETHToLock);
        borrowerUser.totDebtCoveredByRealCollateral += FV;
        loans.createFOL(loanOffer.lender, params.borrower, FV, params.dueDate);
        users[loanOffer.lender].cash.transfer(borrowerUser.cash, params.amount);
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

        LoanOffer storage loanOffer = loanOffers[params.loanOfferId];
        User storage borrowerUser = users[params.borrower];
        User storage lenderUser = users[loanOffer.lender];
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
            if ((r * amountOutLeft) / PERCENT >= loan.getCredit()) {
                deltaAmountIn = loan.getCredit();
                deltaAmountOut = (loan.getCredit() * PERCENT) / r;
            } else {
                deltaAmountIn = (r * amountOutLeft) / PERCENT;
                deltaAmountOut = amountOutLeft;
            }

            loans.createSOL(loanId, loanOffer.lender, params.borrower, deltaAmountIn);
            // NOTE: Transfer deltaAmountOut for each SOL created
            lenderUser.cash.transfer(borrowerUser.cash, deltaAmountOut);
            loanOffer.maxAmount -= deltaAmountOut;
            // amountInLeft -= deltaAmountIn;
            amountOutLeft -= deltaAmountOut;
        }
    }
}
