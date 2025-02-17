// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, User} from "@src/SizeStorage.sol";

import {CreditPosition, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {Action} from "@src/v1.5/libraries/Authorization.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SetUserConfigurationParams {
    // The opening limit borrow CR
    uint256 openingLimitBorrowCR;
    // Whether all credit positions for sale are disabled
    bool allCreditPositionsForSaleDisabled;
    // Whether credit position IDs array are for sale
    bool creditPositionIdsForSale;
    // The credit position IDs array
    uint256[] creditPositionIds;
}

struct SetUserConfigurationOnBehalfOfParams {
    // The input parameters for setting user configuration
    SetUserConfigurationParams params;
    // The address of the account to set user configuration for
    address onBehalfOf;
}

/// @title SetUserConfiguration
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library SetUserConfiguration {
    using LoanLibrary for State;

    /// @notice Validates the input parameters for setting user configuration
    /// @param state The state
    /// @param externalParams The input parameters for setting user configuration
    function validateSetUserConfiguration(
        State storage state,
        SetUserConfigurationOnBehalfOfParams memory externalParams
    ) external view {
        SetUserConfigurationParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorizedOnThisMarket(msg.sender, onBehalfOf, Action.SET_USER_CONFIGURATION)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.SET_USER_CONFIGURATION));
        }

        // validate openingLimitBorrowCR
        // N/A

        // validate allCreditPositionsForSaleDisabled
        // N/A

        // validate creditPositionIdsForSale
        // N/A

        // validate creditPositionIds
        for (uint256 i = 0; i < params.creditPositionIds.length; i++) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionIds[i]);
            if (creditPosition.lender != onBehalfOf) {
                revert Errors.INVALID_CREDIT_POSITION_ID(params.creditPositionIds[i]);
            }

            if (state.getLoanStatus(params.creditPositionIds[i]) != LoanStatus.ACTIVE) {
                revert Errors.LOAN_NOT_ACTIVE(params.creditPositionIds[i]);
            }
        }
    }

    /// @notice Executes the setting of user configuration
    /// @param state The state
    /// @param externalParams The input parameters for setting user configuration
    function executeSetUserConfiguration(
        State storage state,
        SetUserConfigurationOnBehalfOfParams memory externalParams
    ) external {
        SetUserConfigurationParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        User storage user = state.data.users[onBehalfOf];

        user.openingLimitBorrowCR = params.openingLimitBorrowCR;
        user.allCreditPositionsForSaleDisabled = params.allCreditPositionsForSaleDisabled;

        for (uint256 i = 0; i < params.creditPositionIds.length; i++) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionIds[i]);
            creditPosition.forSale = params.creditPositionIdsForSale;
            emit Events.UpdateCreditPosition(
                params.creditPositionIds[i], creditPosition.lender, creditPosition.credit, creditPosition.forSale
            );
        }

        emit Events.SetUserConfiguration(
            msg.sender,
            params.openingLimitBorrowCR,
            params.allCreditPositionsForSaleDisabled,
            params.creditPositionIdsForSale,
            params.creditPositionIds
        );
        emit Events.OnBehalfOfParams(msg.sender, onBehalfOf, uint8(Action.SET_USER_CONFIGURATION), address(0));
    }
}
