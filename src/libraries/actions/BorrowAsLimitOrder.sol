// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowAsLimitOrderParams {
    uint256 maxAmount;
    YieldCurve curveRelativeTime;
}

library BorrowAsLimitOrder {
    function validateBorrowAsLimitOrder(State storage, BorrowAsLimitOrderParams memory params) external pure {
        // validate msg.sender

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate params.curveRelativeTime
        if (params.curveRelativeTime.timeBuckets.length == 0 || params.curveRelativeTime.rates.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (params.curveRelativeTime.timeBuckets.length != params.curveRelativeTime.rates.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
    }

    function executeBorrowAsLimitOrder(State storage state, BorrowAsLimitOrderParams memory params) external {
        state.users[msg.sender].borrowOffer =
            BorrowOffer({maxAmount: params.maxAmount, curveRelativeTime: params.curveRelativeTime});
        emit Events.BorrowAsLimitOrder(params.maxAmount, params.curveRelativeTime);
    }
}
