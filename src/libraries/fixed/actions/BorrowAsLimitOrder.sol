// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {Events} from "@src/libraries/Events.sol";

struct BorrowAsLimitOrderParams {
    YieldCurve curveRelativeTime;
}

library BorrowAsLimitOrder {
    using OfferLibrary for BorrowOffer;

    function validateBorrowAsLimitOrder(State storage state, BorrowAsLimitOrderParams calldata params) external view {
        BorrowOffer memory borrowOffer = BorrowOffer({curveRelativeTime: params.curveRelativeTime});

        // a null offer mean clearing their limit orders
        if (!borrowOffer.isNull()) {
            // validate msg.sender
            // N/A

            // validate openingLimitBorrowCR
            // N/A

            // validate curveRelativeTime
            YieldCurveLibrary.validateYieldCurve(
                params.curveRelativeTime, state.riskConfig.minimumMaturity, state.riskConfig.maximumMaturity
            );
        }
    }

    function executeBorrowAsLimitOrder(State storage state, BorrowAsLimitOrderParams calldata params) external {
        state.data.users[msg.sender].borrowOffer = BorrowOffer({curveRelativeTime: params.curveRelativeTime});
        emit Events.BorrowAsLimitOrder(
            params.curveRelativeTime.maturities,
            params.curveRelativeTime.aprs,
            params.curveRelativeTime.marketRateMultipliers
        );
    }
}
