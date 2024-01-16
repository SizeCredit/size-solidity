// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";

import {FixedLoan} from "@src/libraries/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {State} from "@src/SizeStorage.sol";

import {LiquidateFixedLoan, LiquidateFixedLoanParams} from "@src/libraries/actions/LiquidateFixedLoan.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateFixedLoanWithReplacementParams {
    uint256 loanId;
    address borrower;
    uint256 minimumCollateralRatio;
}

library LiquidateFixedLoanWithReplacement {
    using FixedLoanLibrary for FixedLoan;
    using OfferLibrary for BorrowOffer;
    using Common for State;
    using LiquidateFixedLoan for State;

    function validateLiquidateFixedLoanWithReplacement(
        State storage state,
        LiquidateFixedLoanWithReplacementParams calldata params
    ) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];
        BorrowOffer storage borrowOffer = state._fixed.users[params.borrower].borrowOffer;

        // validate liquidateFixedLoan
        state.validateLiquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: params.loanId, minimumCollateralRatio: params.minimumCollateralRatio})
        );

        // validate loanId
        if (state.getFixedLoanStatus(loan) != FixedLoanStatus.ACTIVE) {
            revert Errors.INVALID_LOAN_STATUS(params.loanId, state.getFixedLoanStatus(loan), FixedLoanStatus.ACTIVE);
        }

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }
    }

    function executeLiquidateFixedLoanWithReplacement(
        State storage state,
        LiquidateFixedLoanWithReplacementParams calldata params
    ) external returns (uint256, uint256) {
        emit Events.LiquidateFixedLoanWithReplacement(params.loanId, params.borrower, params.minimumCollateralRatio);

        FixedLoan storage fol = state._fixed.loans[params.loanId];
        BorrowOffer storage borrowOffer = state._fixed.users[params.borrower].borrowOffer;
        uint256 faceValue = fol.faceValue;
        uint256 dueDate = fol.dueDate;

        uint256 liquidatorProfitCollateralAsset = state.executeLiquidateFixedLoan(
            LiquidateFixedLoanParams({loanId: params.loanId, minimumCollateralRatio: params.minimumCollateralRatio})
        );

        uint256 r = (PERCENT + borrowOffer.getRate(dueDate));
        uint256 amountOut = Math.mulDivDown(faceValue, PERCENT, r);
        uint256 liquidatorProfitBorrowAsset = faceValue - amountOut;

        borrowOffer.maxAmount -= amountOut;

        fol.borrower = params.borrower;
        fol.repaid = false;

        state._fixed.debtToken.mint(params.borrower, faceValue);
        state._fixed.borrowToken.transferFrom(state._general.variablePool, params.borrower, amountOut);
        // TODO evaliate who gets this profit, msg.sender or state._general.feeRecipient
        state._fixed.borrowToken.transferFrom(
            state._general.variablePool, state._general.feeRecipient, liquidatorProfitBorrowAsset
        );

        return (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset);
    }
}
