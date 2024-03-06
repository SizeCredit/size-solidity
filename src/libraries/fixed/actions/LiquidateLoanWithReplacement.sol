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
    uint256 minimumCollateralProfit;
    uint256 deadline;
    uint256 minRate;
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
            LiquidateLoanParams({loanId: params.loanId, minimumCollateralProfit: params.minimumCollateralProfit})
        );

        // validate loanId
        if (state.getLoanStatus(loan) != LoanStatus.ACTIVE) {
            revert Errors.INVALID_LOAN_STATUS(params.loanId, state.getLoanStatus(loan), LoanStatus.ACTIVE);
        }

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }

        // validate params.deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate params.minRate
        uint256 rate = borrowOffer.getRate(state.oracle.marketBorrowRateFeed.getMarketBorrowRate(), loan.fol.dueDate);
        if (rate < params.minRate) {
            revert Errors.RATE_LOWER_THAN_MIN_RATE(rate, params.minRate);
        }
    }

    function validateMinimumCollateralProfit(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        LiquidateLoan.validateMinimumCollateralProfit(
            state,
            LiquidateLoanParams({loanId: params.loanId, minimumCollateralProfit: params.minimumCollateralProfit}),
            liquidatorProfitCollateralToken
        );
    }

    function executeLiquidateLoanWithReplacement(
        State storage state,
        LiquidateLoanWithReplacementParams calldata params
    ) external returns (uint256, uint256) {
        emit Events.LiquidateLoanWithReplacement(params.loanId, params.borrower, params.minimumCollateralProfit);

        Loan storage fol = state.data.loans[params.loanId];
        Loan memory folCopy = fol;
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;

        uint256 liquidatorProfitCollateralAsset = state.executeLiquidateLoan(
            LiquidateLoanParams({loanId: params.loanId, minimumCollateralProfit: params.minimumCollateralProfit})
        );

        uint256 rate = borrowOffer.getRate(state.oracle.marketBorrowRateFeed.getMarketBorrowRate(), folCopy.fol.dueDate);
        uint256 amountOut = Math.mulDivDown(folCopy.faceValue(), PERCENT, PERCENT + rate);
        uint256 liquidatorProfitBorrowAsset = folCopy.faceValue() - amountOut;

        fol.generic.borrower = params.borrower;
        fol.fol.startDate = block.timestamp;
        fol.fol.liquidityIndexAtRepayment = 0;
        fol.fol.issuanceValue = amountOut;
        fol.fol.rate = rate;

        state.data.debtToken.mint(params.borrower, folCopy.getDebt());
        state.transferBorrowAToken(address(this), params.borrower, amountOut);
        state.transferBorrowAToken(address(this), state.config.feeRecipient, liquidatorProfitBorrowAsset);

        return (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset);
    }
}
