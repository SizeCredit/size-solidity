// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {CreditPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SetCreditForSaleParams {
    bool creditPositionsForSaleDisabled;
    bool forSale;
    uint256[] creditPositionIds;
}

library SetCreditForSale {
    using LoanLibrary for State;

    function validateSetCreditForSale(State storage state, SetCreditForSaleParams calldata params) external view {
        // validate msg.sender
        // N/A

        // validate creditPositionId
        for (uint256 i = 0; i < params.creditPositionIds.length; i++) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionIds[i]);
            if (creditPosition.lender != msg.sender) {
                revert Errors.INVALID_CREDIT_POSITION_ID(params.creditPositionIds[i]);
            }

            if (state.getLoanStatus(params.creditPositionIds[i]) != LoanStatus.ACTIVE) {
                revert Errors.LOAN_NOT_ACTIVE(params.creditPositionIds[i]);
            }
            if (creditPosition.credit == 0) {
                revert Errors.CREDIT_POSITION_ALREADY_CLAIMED(params.creditPositionIds[i]);
            }
        }

        // validate forSale
        // N/A

        // validate allCreditPositionsForSale
        // N/A
    }

    function executeSetCreditForSale(State storage state, SetCreditForSaleParams calldata params) external {
        User storage user = state.data.users[msg.sender];

        user.creditPositionsForSaleDisabled = params.creditPositionsForSaleDisabled;

        for (uint256 i = 0; i < params.creditPositionIds.length; i++) {
            CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionIds[i]);
            creditPosition.forSale = params.forSale;
        }

        emit Events.SetCreditForSale(params.creditPositionsForSaleDisabled, params.forSale, params.creditPositionIds);
    }
}
