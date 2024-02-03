// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {LiquidateFixedLoan, LiquidateFixedLoanParams} from "@src/libraries/fixed/actions/LiquidateFixedLoan.sol";

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
    using VariableLibrary for State;
    using FixedLoanLibrary for State;
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

        uint256 r = (PERCENT + borrowOffer.getRate(state._general.marketBorrowRateFeed.getMarketBorrowRate(), dueDate));
        uint256 amountOut = Math.mulDivDown(faceValue, PERCENT, r);
        uint256 liquidatorProfitBorrowAsset = faceValue - amountOut;

        fol.borrower = params.borrower;
        fol.startDate = block.timestamp;
        fol.liquidityIndexAtRepayment = 0;
        fol.debt += faceValue;

        state._fixed.debtToken.mint(params.borrower, faceValue);
        state.transferBorrowAToken(address(this), params.borrower, amountOut);
        state.transferBorrowAToken(address(this), state._general.feeRecipient, liquidatorProfitBorrowAsset);

        return (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset);
    }
}
