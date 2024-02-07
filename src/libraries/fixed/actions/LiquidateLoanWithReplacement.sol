// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {LiquidateLoan, LiquidateLoanParams} from "@src/libraries/fixed/actions/LiquidateLoan.sol";

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
    using VariableLibrary for State;
    using LoanLibrary for State;
    using LiquidateLoan for State;

    function validateLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external view {
        Loan storage loan = state.data.loans[params.loanId];
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;

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

        Loan storage fol = state.data.loans[params.loanId];
        Loan memory folCopy = fol;
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;

        uint256 liquidatorProfitCollateralAsset = state.executeLiquidateLoan(
            LiquidateLoanParams({loanId: params.loanId, minimumCollateralRatio: params.minimumCollateralRatio})
        );

        uint256 rate = borrowOffer.getRate(state.oracle.marketBorrowRateFeed.getMarketBorrowRate(), folCopy.fol.dueDate);
        uint256 amountOut = Math.mulDivDown(folCopy.faceValue(), PERCENT, PERCENT + rate);
        uint256 liquidatorProfitBorrowAsset = folCopy.faceValue() - amountOut;

        fol.generic.borrower = params.borrower;
        fol.fol.startDate = block.timestamp;
        fol.fol.liquidityIndexAtRepayment = 0;
        fol.fol.issuanceValue = amountOut;
        fol.fol.rate = rate;

        state.data.debtToken.mint(params.borrower, state.getDebt(folCopy));
        state.transferBorrowAToken(address(this), params.borrower, amountOut);
        state.transferBorrowAToken(address(this), state.config.feeRecipient, liquidatorProfitBorrowAsset);

        return (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset);
    }
}
