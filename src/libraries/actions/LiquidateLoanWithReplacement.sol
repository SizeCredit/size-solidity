// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/actions/LiquidateLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateLoanWithReplacementParams {
    uint256 loanId;
    address borrower;
}

library LiquidateLoanWithReplacement {
    using LoanLibrary for Loan;
    using OfferLibrary for BorrowOffer;

    function validateLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external view {
        Loan memory loan = state.loans[params.loanId];
        BorrowOffer memory borrowOffer = state.users[params.borrower].borrowOffer;

        // validate liquidateLoan
        LiquidateLoan.validateLiquidateLoan(state, LiquidateLoanParams({loanId: params.loanId}));

        // validate loanId
        if (loan.getLoanStatus(state.loans) != LoanStatus.ACTIVE) {
            revert Errors.INVALID_LOAN_STATUS(params.loanId, loan.getLoanStatus(state.loans), LoanStatus.ACTIVE);
        }

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }
    }

    function executeLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external returns (uint256) {
        Loan storage fol = state.loans[params.loanId];
        BorrowOffer storage borrowOffer = state.users[params.borrower].borrowOffer;
        uint256 FV = fol.FV;
        uint256 dueDate = fol.getDueDate(state.loans);

        LiquidateLoan.executeLiquidateLoan(state, LiquidateLoanParams({loanId: params.loanId}));

        uint256 r = (PERCENT + borrowOffer.getRate(dueDate));
        uint256 amountOut = FixedPointMathLib.mulDivDown(FV, PERCENT, r);
        uint256 liquidatorProfitBorrowAsset = FV - amountOut;

        borrowOffer.maxAmount -= amountOut;

        fol.borrower = params.borrower;
        fol.repaid = false;

        state.debtToken.mint(params.borrower, FV);
        state.borrowToken.transferFrom(state.protocolVault, params.borrower, amountOut);
        // TODO evaliate who gets this profit, msg.sender or state.feeRecipient
        state.borrowToken.transferFrom(state.protocolVault, state.feeRecipient, liquidatorProfitBorrowAsset);

        return liquidatorProfitBorrowAsset;
    }
}