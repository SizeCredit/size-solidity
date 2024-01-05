// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowAsLimitOrderParams {
    uint256 maxAmount;
    YieldCurve curveRelativeTime;
}

library BorrowAsLimitOrder {
    function validateBorrowAsLimitOrder(State storage, BorrowAsLimitOrderParams calldata params) external pure {
        // validate msg.sender

        // validate maxAmount
        if (params.maxAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate curveRelativeTime
        YieldCurveLibrary.validateYieldCurve(params.curveRelativeTime);
    }

    function executeBorrowAsLimitOrder(State storage state, BorrowAsLimitOrderParams calldata params) external {
        state.users[msg.sender].borrowOffer =
            BorrowOffer({maxAmount: params.maxAmount, curveRelativeTime: params.curveRelativeTime});
        emit Events.BorrowAsLimitOrder(params.maxAmount, params.curveRelativeTime);
    }
}
