// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {User} from "@src/libraries/UserLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LendAsLimitOrderParams {
    uint256 maxAmount;
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

library LendAsLimitOrder {
    function validateLendAsLimitOrder(State storage state, LendAsLimitOrderParams calldata params) external view {
        // validate msg.sender

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        if (params.maxAmount > state.borrowToken.balanceOf(msg.sender)) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowToken.balanceOf(msg.sender), params.maxAmount);
        }

        // validate maxDueDate
        if (params.maxDueDate == 0) {
            revert Errors.NULL_MAX_DUE_DATE();
        }
        if (params.maxDueDate < block.timestamp) {
            revert Errors.PAST_MAX_DUE_DATE(params.maxDueDate);
        }

        // validate params.curveRelativeTime
        if (params.curveRelativeTime.timeBuckets.length == 0 || params.curveRelativeTime.rates.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (params.curveRelativeTime.timeBuckets.length != params.curveRelativeTime.rates.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
    }

    function executeLendAsLimitOrder(State storage state, LendAsLimitOrderParams calldata params) external {
        state.users[msg.sender].loanOffer = LoanOffer({
            maxAmount: params.maxAmount,
            maxDueDate: params.maxDueDate,
            curveRelativeTime: params.curveRelativeTime
        });
        emit Events.LendAsLimitOrder(params.maxAmount, params.maxDueDate, params.curveRelativeTime);
    }
}
