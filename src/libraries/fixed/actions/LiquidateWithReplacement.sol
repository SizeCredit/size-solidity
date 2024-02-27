// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Liquidate, LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateWithReplacementParams {
    uint256 debtPositionId;
    address borrower;
    uint256 minimumCollateralProfit;
    uint256 deadline;
    uint256 minRatePerMaturity;
}

library LiquidateWithReplacement {
    using LoanLibrary for CreditPosition;
    using OfferLibrary for BorrowOffer;
    using VariableLibrary for State;
    using LoanLibrary for State;
    using Liquidate for State;
    using LoanLibrary for DebtPosition;

    function validateLiquidateWithReplacement(State storage state, LiquidateWithReplacementParams calldata params)
        external
        view
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;
        uint256 ratePerMaturity =
            borrowOffer.getRatePerMaturity(state.oracle.marketBorrowRateFeed, debtPosition.dueDate);

        // validate liquidate
        state.validateLiquidate(
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit
            })
        );

        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) != LoanStatus.ACTIVE) {
            revert Errors.LOAN_NOT_ACTIVE(params.debtPositionId);
        }

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minRatePerMaturity
        if (ratePerMaturity < params.minRatePerMaturity) {
            revert Errors.RATE_PER_MATURITY_LOWER_THAN_MIN_RATE(ratePerMaturity, params.minRatePerMaturity);
        }
    }

    function validateMinimumCollateralProfit(
        State storage state,
        LiquidateWithReplacementParams calldata params,
        uint256 liquidatorProfitCollateralToken
    ) external pure {
        Liquidate.validateMinimumCollateralProfit(
            state,
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit
            }),
            liquidatorProfitCollateralToken
        );
    }

    function executeLiquidateWithReplacement(State storage state, LiquidateWithReplacementParams calldata params)
        external
        returns (uint256, uint256)
    {
        emit Events.LiquidateWithReplacement(params.debtPositionId, params.borrower, params.minimumCollateralProfit);

        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        DebtPosition memory debtPositionCopy = debtPosition;
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;

        uint256 liquidatorProfitCollateralAsset = state.executeLiquidate(
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit
            })
        );

        uint256 ratePerMaturity =
            borrowOffer.getRatePerMaturity(state.oracle.marketBorrowRateFeed, debtPositionCopy.dueDate);
        uint256 issuanceValue = Math.mulDivDown(debtPositionCopy.faceValue, PERCENT, PERCENT + ratePerMaturity);
        uint256 liquidatorProfitBorrowAsset = debtPositionCopy.faceValue - issuanceValue;

        debtPosition.borrower = params.borrower;
        debtPosition.startDate = block.timestamp;
        debtPosition.issuanceValue = issuanceValue;
        debtPosition.liquidityIndexAtRepayment = 0;

        state.data.debtToken.mint(params.borrower, debtPositionCopy.getDebt());
        state.transferBorrowAToken(address(this), params.borrower, issuanceValue);
        state.transferBorrowAToken(address(this), state.config.feeRecipient, liquidatorProfitBorrowAsset);

        return (liquidatorProfitCollateralAsset, liquidatorProfitBorrowAsset);
    }
}
