// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math} from "@src/libraries/Math.sol";

import {PERCENT} from "@src/libraries/Math.sol";

import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Liquidate, LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateWithReplacementParams {
    uint256 debtPositionId;
    address borrower;
    uint256 minimumCollateralProfit;
    uint256 deadline;
    uint256 minAPR;
}

library LiquidateWithReplacement {
    using LoanLibrary for CreditPosition;
    using OfferLibrary for BorrowOffer;

    using LoanLibrary for State;
    using Liquidate for State;
    using LoanLibrary for DebtPosition;

    function validateLiquidateWithReplacement(State storage state, LiquidateWithReplacementParams calldata params)
        external
        view
    {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;

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
        uint256 tenor = debtPosition.dueDate - block.timestamp;
        if (tenor < state.riskConfig.minimumTenor) {
            revert Errors.TENOR_BELOW_MINIMUM_TENOR(tenor, state.riskConfig.minimumTenor);
        }

        // validate borrower
        if (borrowOffer.isNull()) {
            revert Errors.INVALID_BORROW_OFFER(params.borrower);
        }

        // validate deadline
        if (params.deadline < block.timestamp) {
            revert Errors.PAST_DEADLINE(params.deadline);
        }

        // validate minAPR
        uint256 apr = borrowOffer.getAPRByTenor(state.oracle.variablePoolBorrowRateFeed, tenor);
        if (apr < params.minAPR) {
            revert Errors.APR_LOWER_THAN_MIN_APR(apr, params.minAPR);
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
        returns (uint256, uint256, uint256)
    {
        emit Events.LiquidateWithReplacement(params.debtPositionId, params.borrower, params.minimumCollateralProfit);

        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        DebtPosition memory debtPositionCopy = debtPosition;
        BorrowOffer storage borrowOffer = state.data.users[params.borrower].borrowOffer;
        uint256 tenor = debtPositionCopy.dueDate - block.timestamp;

        uint256 liquidatorProfitCollateralToken = state.executeLiquidate(
            LiquidateParams({
                debtPositionId: params.debtPositionId,
                minimumCollateralProfit: params.minimumCollateralProfit
            })
        );

        uint256 ratePerTenor = borrowOffer.getRatePerTenor(state.oracle.variablePoolBorrowRateFeed, tenor);
        uint256 issuanceValue = Math.mulDivDown(debtPositionCopy.futureValue, PERCENT, PERCENT + ratePerTenor);
        uint256 liquidatorProfitBorrowToken = debtPositionCopy.futureValue - issuanceValue;

        debtPosition.borrower = params.borrower;
        debtPosition.futureValue = debtPositionCopy.futureValue;
        debtPosition.liquidityIndexAtRepayment = 0;

        emit Events.UpdateDebtPosition(
            params.debtPositionId,
            debtPosition.borrower,
            debtPosition.futureValue,
            debtPosition.dueDate,
            debtPosition.liquidityIndexAtRepayment
        );

        state.data.debtToken.mint(params.borrower, debtPosition.futureValue);
        state.data.borrowAToken.transferFrom(address(this), params.borrower, issuanceValue);
        state.data.borrowAToken.transferFrom(address(this), state.feeConfig.feeRecipient, liquidatorProfitBorrowToken);

        return (issuanceValue, liquidatorProfitCollateralToken, liquidatorProfitBorrowToken);
    }
}
