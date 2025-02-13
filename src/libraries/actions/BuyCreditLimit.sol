// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";

struct BuyCreditLimitParams {
    // The maximum due date of the loan offer
    uint256 maxDueDate;
    // The yield curve of the loan offer
    YieldCurve curveRelativeTime;
}

/// @title BuyCreditLimit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for buying credit (lending) as a limit order
library BuyCreditLimit {
    using OfferLibrary for LimitOrder;

    /// @notice Validates the input parameters for buying credit as a limit order
    /// @param state The state
    /// @param params The input parameters for buying credit as a limit order
    function validateBuyCreditLimit(State storage state, BuyCreditLimitParams calldata params) external view {
        LimitOrder memory loanOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});

        // a null offer mean clearing their limit order
        if (!loanOffer.isNull()) {
            // validate msg.sender
            // N/A

            // validate loanOffer
            loanOffer.validateLimitOrder(state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }
    }

    /// @notice Executes the buying of credit as a limit order
    /// @param state The state
    /// @param params The input parameters for buying credit as a limit order
    /// @dev A null offer means clearing a user's loan limit order
    function executeBuyCreditLimit(State storage state, BuyCreditLimitParams calldata params) external {
        emit Events.BuyCreditLimit(
            msg.sender,
            params.maxDueDate,
            params.curveRelativeTime.tenors,
            params.curveRelativeTime.aprs,
            params.curveRelativeTime.marketRateMultipliers
        );

        state.data.users[msg.sender].loanOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});
    }
}
