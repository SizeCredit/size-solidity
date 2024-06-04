// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/core/SizeStorage.sol";
import {BorrowOffer, OfferLibrary} from "@src/core/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/core/libraries/fixed/YieldCurveLibrary.sol";

import {Events} from "@src/core/libraries/Events.sol";

struct SellCreditLimitParams {
    YieldCurve curveRelativeTime;
}

/// @title SellCreditLimit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library SellCreditLimit {
    using OfferLibrary for BorrowOffer;

    function validateSellCreditLimit(State storage state, SellCreditLimitParams calldata params) external view {
        BorrowOffer memory borrowOffer = BorrowOffer({curveRelativeTime: params.curveRelativeTime});

        // a null offer mean clearing their limit orders
        if (!borrowOffer.isNull()) {
            // validate msg.sender
            // N/A

            // validate openingLimitBorrowCR
            // N/A

            // validate curveRelativeTime
            YieldCurveLibrary.validateYieldCurve(
                params.curveRelativeTime, state.riskConfig.minTenor, state.riskConfig.maxTenor
            );
        }
    }

    function executeSellCreditLimit(State storage state, SellCreditLimitParams calldata params) external {
        state.data.users[msg.sender].borrowOffer = BorrowOffer({curveRelativeTime: params.curveRelativeTime});
        emit Events.SellCreditLimit(
            params.curveRelativeTime.tenors,
            params.curveRelativeTime.aprs,
            params.curveRelativeTime.marketRateMultipliers
        );
    }
}
