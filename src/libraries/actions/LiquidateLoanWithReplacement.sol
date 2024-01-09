// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {State} from "@src/SizeStorage.sol";

import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateLoanWithReplacementParams {
    uint256 loanId;
    address borrower;
    uint256 minimumCollateralRatio;
}

library LiquidateLoanWithReplacement {
    using LoanLibrary for Loan;
    using OfferLibrary for BorrowOffer;
    using Common for State;
    using LiquidateLoan for State;

    function validateLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external view {
        Loan storage loan = state.loans[params.loanId];
        BorrowOffer storage borrowOffer = state.users[params.borrower].borrowOffer;

        // validate liquidateLoan
        state.validateLiquidateLoan(
            LiquidateLoanParams({loanId: params.loanId, minimumCollateralRatio: params.minimumCollateralRatio})
        );

        // validate loanId
        if (state.getLoanStatus(loan) != LoanStatus.ACTIVE) {
            revert Errors.INVALID_LOAN_STATUS(params.loanId, state.getLoanStatus(loan), LoanStatus.ACTIVE);
        }

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }
    }

    function executeLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external returns (uint256, uint256) {
        emit Events.LiquidateLoanWithReplacement(params.loanId, params.borrower, params.minimumCollateralRatio);

        Loan storage fol = state.loans[params.loanId];
        BorrowOffer storage borrowOffer = state.users[params.borrower].borrowOffer;
        uint256 faceValue = fol.faceValue;
        uint256 dueDate = fol.dueDate;

        uint256 liquidatorProfitCollateralAsset = state.executeLiquidateLoan(
            LiquidateLoanParams({loanId: params.loanId, minimumCollateralRatio: params.minimumCollateralRatio})
        );

        uint256 r = (PERCENT + borrowOffer.getRate(dueDate));
        uint256 amountOut = Math.mulDivDown(faceValue, PERCENT, r);
        uint256 liquidatorProfitBorrowAsset = faceValue - amountOut;

        borrowOffer.maxAmount -= amountOut;

        fol.borrower = params.borrower;
        fol.repaid = false;

        state.tokens.debtToken.mint(params.borrower, faceValue);
        state.tokens.borrowToken.transferFrom(state.config.variablePool, params.borrower, amountOut);
        // TODO evaliate who gets this profit, msg.sender or state.config.feeRecipient
        state.tokens.borrowToken.transferFrom(
            state.config.variablePool, state.config.feeRecipient, liquidatorProfitBorrowAsset
        );

        return (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset);
    }
}
