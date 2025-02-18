// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";
import {Action} from "@src/v1.5/libraries/Authorization.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateParams {
    // The credit position ID
    uint256 creditPositionId;
}

struct SelfLiquidateOnBehalfOfParams {
    // The parameters for the self-liquidate
    SelfLiquidateParams params;
    // The account to self-liquidate the credit position for
    address onBehalfOf;
    // The account to transfer the collateral to
    address recipient;
}

/// @title SelfLiquidate
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for self-liquidating a credit position
library SelfLiquidate {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    /// @notice Validates the input parameters for self-liquidating a credit position
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for self-liquidating a credit position
    function validateSelfLiquidate(State storage state, SelfLiquidateOnBehalfOfParams memory externalParams)
        external
        view
    {
        SelfLiquidateParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;
        address recipient = externalParams.recipient;

        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.SELF_LIQUIDATE)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.SELF_LIQUIDATE));
        }
        if (onBehalfOf != creditPosition.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(onBehalfOf, creditPosition.lender);
        }

        // validate recipient
        if (recipient == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate creditPositionId
        if (!state.isCreditPositionSelfLiquidatable(params.creditPositionId)) {
            revert Errors.LOAN_NOT_SELF_LIQUIDATABLE(
                params.creditPositionId,
                state.collateralRatio(debtPosition.borrower),
                uint8(state.getLoanStatus(params.creditPositionId))
            );
        }
    }

    /// @notice Executes the self-liquidation of a credit position
    /// @param state The state of the protocol
    /// @param externalParams The input parameters for self-liquidating a credit position
    function executeSelfLiquidate(State storage state, SelfLiquidateOnBehalfOfParams memory externalParams) external {
        SelfLiquidateParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;
        address recipient = externalParams.recipient;

        emit Events.SelfLiquidate(msg.sender, params.creditPositionId);
        emit Events.OnBehalfOfParams(msg.sender, onBehalfOf, uint8(Action.SELF_LIQUIDATE), recipient);

        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);

        // debt and credit reduction
        state.reduceDebtAndCredit(creditPosition.debtPositionId, params.creditPositionId, creditPosition.credit);

        state.data.collateralToken.transferFrom(debtPosition.borrower, recipient, assignedCollateral);
    }
}
