// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {FixedLoanOffer} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LendAsLimitOrderParams {
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

library LendAsLimitOrder {
    using VariableLibrary for State;

    function validateLendAsLimitOrder(State storage, LendAsLimitOrderParams calldata params) external view {
        // validate msg.sender

        // validate maxDueDate
        if (params.maxDueDate == 0) {
            revert Errors.NULL_MAX_DUE_DATE();
        }
        if (params.maxDueDate < block.timestamp) {
            revert Errors.PAST_MAX_DUE_DATE(params.maxDueDate);
        }

        // validate params.curveRelativeTime
        YieldCurveLibrary.validateYieldCurve(params.curveRelativeTime);
    }

    function executeLendAsLimitOrder(State storage state, LendAsLimitOrderParams calldata params) external {
        state._fixed.users[msg.sender].loanOffer =
            FixedLoanOffer({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});
        emit Events.LendAsLimitOrder(params.maxDueDate, params.curveRelativeTime);
    }
}
