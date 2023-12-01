// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {VaultLibrary, Vault} from "@src/libraries/VaultLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct BorrowAsMarketOrderParams {
    address borrower;
    address lender;
    uint256 amount;
    uint256 dueDate;
    bool exactAmountIn;
    uint256[] virtualCollateralLoansIds;
}

library BorrowAsMarketOrder {
    using OfferLibrary for LoanOffer;
    using VaultLibrary for Vault;
    using LoanLibrary for Loan;
    using LoanLibrary for Loan[];

    function validateBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external view {
        User memory lenderUser = state.users[params.lender];
        LoanOffer memory loanOffer = lenderUser.loanOffer;

        // validate params.borrower
        // N/A

        // validate params.lender
        if (loanOffer.isNull()) {
            revert Errors.INVALID_LOAN_OFFER(params.lender);
        }

        // validate params.amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        if (params.amount > loanOffer.maxAmount) {
            revert Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT(params.amount, loanOffer.maxAmount);
        }

        // validate params.dueDate
        if (params.dueDate < block.timestamp) {
            revert Errors.PAST_DUE_DATE(params.dueDate);
        }
        if (params.dueDate > loanOffer.maxDueDate) {
            revert Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE(params.dueDate, loanOffer.maxDueDate);
        }

        // validate params.exactAmountIn
        // N/A

        // validate params.virtualCollateralLoansIds
        for (uint256 i = 0; i < params.virtualCollateralLoansIds.length; ++i) {
            uint256 loanId = params.virtualCollateralLoansIds[i];
            Loan memory loan = state.loans[loanId];

            if (params.borrower != loan.lender) {
                revert Errors.BORROWER_IS_NOT_LENDER(params.borrower, loan.lender);
            }
            if (params.dueDate < loan.getDueDate(state.loans)) {
                revert Errors.DUE_DATE_LOWER_THAN_LOAN_DUE_DATE(params.dueDate, loan.getDueDate(state.loans));
            }
        }
    }

    function executeBorrowAsMarketOrder(State storage state, BorrowAsMarketOrderParams memory params) external {
        params.amount = _borrowWithVirtualCollateral(state, params);
        _borrowWithRealCollateral(state, params);
    }

    /**
     * @notice Borrow with virtual collateral, an internal state-modifying function.
     * @dev The `amount` is initialized to `amountOutLeft`, which is decreased as more and more SOLs are created
     */
    function _borrowWithVirtualCollateral(State storage state, BorrowAsMarketOrderParams memory params)
        internal
        returns (uint256 amountOutLeft)
    {
        //  amountIn: Amount of future cashflow to exit
        //  amountOut: Amount of cash to borrow at present time

        User storage borrowerUser = state.users[params.borrower];
        User storage lenderUser = state.users[params.lender];

        LoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 r = PERCENT + loanOffer.getRate(params.dueDate);

        amountOutLeft = params.exactAmountIn ? FixedPointMathLib.mulDivUp(params.amount, PERCENT, r) : params.amount;

        for (uint256 i = 0; i < params.virtualCollateralLoansIds.length; ++i) {
            // Full amount borrowed
            if (amountOutLeft == 0) {
                break;
            }

            uint256 loanId = params.virtualCollateralLoansIds[i];
            Loan memory loan = state.loans[loanId];

            uint256 deltaAmountIn;
            uint256 deltaAmountOut;
            if (FixedPointMathLib.mulDivUp(r, amountOutLeft, PERCENT) > loan.getCredit()) {
                deltaAmountIn = loan.getCredit();
                deltaAmountOut = FixedPointMathLib.mulDivUp(loan.getCredit(), PERCENT, r);
            } else {
                deltaAmountIn = FixedPointMathLib.mulDivUp(r, amountOutLeft, PERCENT);
                deltaAmountOut = amountOutLeft;
            }

            state.loans.createSOL(loanId, params.lender, params.borrower, deltaAmountIn);
            // NOTE: Transfer deltaAmountOut for each SOL created
            lenderUser.borrowAsset.transfer(borrowerUser.borrowAsset, deltaAmountOut);
            loanOffer.maxAmount -= deltaAmountOut;
            amountOutLeft -= deltaAmountOut;
        }
    }

    /**
     * @notice Borrow with real collateral, an internal state-modifying function.
     * @dev Cover the remaining amount with real collateral
     */
    function _borrowWithRealCollateral(State storage state, BorrowAsMarketOrderParams memory params) internal {
        if (params.amount == 0) {
            return;
        }

        User storage borrowerUser = state.users[params.borrower];
        User storage lenderUser = state.users[params.lender];

        LoanOffer storage loanOffer = lenderUser.loanOffer;

        uint256 r = PERCENT + loanOffer.getRate(params.dueDate);

        uint256 FV = FixedPointMathLib.mulDivUp(r, params.amount, PERCENT);
        uint256 maxCollateralToLock = FixedPointMathLib.mulDivUp(FV, state.CROpening, state.priceFeed.getPrice());
        borrowerUser.collateralAsset.lock(maxCollateralToLock);
        borrowerUser.totalDebtCoveredByRealCollateral += FV;
        state.loans.createFOL(params.lender, params.borrower, FV, params.dueDate);
        lenderUser.borrowAsset.transfer(borrowerUser.borrowAsset, params.amount);
        loanOffer.maxAmount -= params.amount;
    }
}
