// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State, User} from "@src/core/SizeStorage.sol";

import {CreditPosition, LoanLibrary, LoanStatus} from "@src/core/libraries/fixed/LoanLibrary.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";

struct SetUserConfigurationParams {
    uint256 openingLimitBorrowCR;
    bool allCreditPositionsForSaleDisabled;
    bool creditPositionIdsForSale;
    uint256[] creditPositionIds;
}

library SetUserConfiguration {
    using LoanLibrary for State;

    function validateSetUserConfiguration(State storage state, SetUserConfigurationParams calldata params)
        external
        view
    {
        // validate msg.sender
        // N/A

        // validate openingLimitBorrowCR
        // N/A

        // validate allCreditPositionsForSaleDisabled
        // N/A

        // validate creditPositionIdsForSale
        // N/A

        // validate creditPositionIds
        for (uint256 i = 0; i < params.creditPositionIds.length; i++) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionIds[i]);
            if (creditPosition.lender != msg.sender) {
                revert Errors.INVALID_CREDIT_POSITION_ID(params.creditPositionIds[i]);
            }

            if (state.getLoanStatus(params.creditPositionIds[i]) != LoanStatus.ACTIVE) {
                revert Errors.LOAN_NOT_ACTIVE(params.creditPositionIds[i]);
            }
        }
    }

    function executeSetUserConfiguration(State storage state, SetUserConfigurationParams calldata params) external {
        User storage user = state.data.users[msg.sender];

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
            params.openingLimitBorrowCR,
            params.allCreditPositionsForSaleDisabled,
            params.creditPositionIdsForSale,
            params.creditPositionIds
        );
    }
}
