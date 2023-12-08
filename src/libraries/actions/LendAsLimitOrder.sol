// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {User} from "@src/libraries/UserLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LendAsLimitOrderParams {
    address lender;
    uint256 maxAmount;
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

library LendAsLimitOrder {
    function validateLendAsLimitOrder(State storage state, LendAsLimitOrderParams memory params) external view {
        User memory lenderUser = state.users[params.lender];

        // validate params.lender
        // N/A

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        if (params.maxAmount > lenderUser.borrowAsset.free) {
            revert Errors.NOT_ENOUGH_FREE_CASH(lenderUser.borrowAsset.free, params.maxAmount);
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

    function executeLendAsLimitOrder(State storage state, LendAsLimitOrderParams memory params) external {
        state.users[params.lender].loanOffer = LoanOffer({
            maxAmount: params.maxAmount,
            maxDueDate: params.maxDueDate,
            curveRelativeTime: params.curveRelativeTime
        });
        emit Events.LendAsLimitOrder(params.maxAmount, params.maxDueDate, params.curveRelativeTime);
    }
}
