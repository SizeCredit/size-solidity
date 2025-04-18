// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/market/SizeStorage.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/market/libraries/LoanLibrary.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

struct CompensateParams {
    // The credit position ID with debt to repay
    uint256 creditPositionWithDebtToRepayId;
    // The credit position ID to compensate
    uint256 creditPositionToCompensateId;
    // The amount to compensate
    // The maximum amount to compensate is the minimum of the credits
    uint256 amount;
}

struct CompensateOnBehalfOfParams {
    // The parameters for the compensation
    CompensateParams params;
    // The account to compensate the credit position for
    address onBehalfOf;
}

/// @title Compensate
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for compensating a credit position
library Compensate {
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;

    using RiskLibrary for State;

    /// @notice Validates the input parameters for compensating a credit position
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for compensating a credit position
    function validateCompensate(State storage state, CompensateOnBehalfOfParams memory externalParams) external view {
        CompensateParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        CreditPosition storage creditPositionWithDebtToRepay =
            state.getCreditPosition(params.creditPositionWithDebtToRepayId);
        DebtPosition storage debtPositionToRepay =
            state.getDebtPositionByCreditPositionId(params.creditPositionWithDebtToRepayId);

        uint256 amountToCompensate = Math.min(params.amount, creditPositionWithDebtToRepay.credit);

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.COMPENSATE)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.COMPENSATE));
        }
        if (onBehalfOf != debtPositionToRepay.borrower) {
            revert Errors.COMPENSATOR_IS_NOT_BORROWER(onBehalfOf, debtPositionToRepay.borrower);
        }

        // validate creditPositionWithDebtToRepayId
        if (state.getLoanStatus(params.creditPositionWithDebtToRepayId) != LoanStatus.ACTIVE) {
            revert Errors.LOAN_NOT_ACTIVE(params.creditPositionWithDebtToRepayId);
        }

        // validate creditPositionToCompensateId
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(params.creditPositionToCompensateId);
        DebtPosition storage debtPositionToCompensate =
            state.getDebtPositionByCreditPositionId(params.creditPositionToCompensateId);
        if (!state.isCreditPositionTransferrable(params.creditPositionToCompensateId)) {
            revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                params.creditPositionToCompensateId,
                uint8(state.getLoanStatus(params.creditPositionToCompensateId)),
                state.collateralRatio(debtPositionToCompensate.borrower)
            );
        }
        if (
            debtPositionToRepay.dueDate
                < state.getDebtPositionByCreditPositionId(params.creditPositionToCompensateId).dueDate
        ) {
            revert Errors.DUE_DATE_NOT_COMPATIBLE(
                params.creditPositionWithDebtToRepayId, params.creditPositionToCompensateId
            );
        }
        if (creditPositionToCompensate.lender != debtPositionToRepay.borrower) {
            revert Errors.INVALID_LENDER(creditPositionToCompensate.lender);
        }
        if (params.creditPositionToCompensateId == params.creditPositionWithDebtToRepayId) {
            revert Errors.INVALID_CREDIT_POSITION_ID(params.creditPositionToCompensateId);
        }
        amountToCompensate = Math.min(amountToCompensate, creditPositionToCompensate.credit);

        // validate amount
        if (amountToCompensate == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    /// @notice Executes the compensating of a credit position
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for compensating a credit position
    function executeCompensate(State storage state, CompensateOnBehalfOfParams memory externalParams) external {
        CompensateParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        emit Events.Compensate(
            msg.sender,
            onBehalfOf,
            params.creditPositionWithDebtToRepayId,
            params.creditPositionToCompensateId,
            params.amount
        );

        CreditPosition storage creditPositionWithDebtToRepay =
            state.getCreditPosition(params.creditPositionWithDebtToRepayId);

        CreditPosition memory creditPositionToCompensate = state.getCreditPosition(params.creditPositionToCompensateId);
        uint256 amountToCompensate =
            Math.min(params.amount, Math.min(creditPositionWithDebtToRepay.credit, creditPositionToCompensate.credit));
        bool shouldChargeFragmentationFee = amountToCompensate != creditPositionToCompensate.credit;

        // debt and credit reduction
        state.reduceDebtAndCredit(
            creditPositionWithDebtToRepay.debtPositionId, params.creditPositionWithDebtToRepayId, amountToCompensate
        );

        // credit emission
        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionToCompensateId,
            lender: creditPositionWithDebtToRepay.lender,
            credit: amountToCompensate,
            forSale: creditPositionWithDebtToRepay.forSale
        });
        if (shouldChargeFragmentationFee) {
            // charge the fragmentation fee in collateral tokens
            uint256 fragmentationFeeInCollateral =
                state.debtTokenAmountToCollateralTokenAmount(state.feeConfig.fragmentationFee);
            state.data.collateralToken.transferFrom(
                onBehalfOf, state.feeConfig.feeRecipient, fragmentationFeeInCollateral
            );
        }
    }
}
