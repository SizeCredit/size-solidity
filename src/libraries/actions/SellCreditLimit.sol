// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";
import {LimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {Events} from "@src/libraries/Events.sol";

struct SellCreditLimitParams {
    // The maximum due date of the borrow offer
    uint256 maxDueDate;
    // The yield curve of the borrow offer
    YieldCurve curveRelativeTime;
}

/// @title SellCreditLimit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for selling credit (borrowing) as a limit order
library SellCreditLimit {
    using OfferLibrary for LimitOrder;

    /// @notice Validates the input parameters for selling credit as a limit order
    /// @param state The state
    /// @param params The input parameters for selling credit as a limit order
    function validateSellCreditLimit(State storage state, SellCreditLimitParams calldata params) external view {
        LimitOrder memory borrowOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});

        // a null offer mean clearing their limit order
        if (!borrowOffer.isNull()) {
            // validate msg.sender
            // N/A

            // validate borrowOffer
            borrowOffer.validateLimitOrder(state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }
    }

    /// @notice Executes the selling of credit as a limit order
    /// @param state The state
    /// @param params The input parameters for selling credit as a limit order
    /// @dev A null offer means clearing a user's borrow limit order
    function executeSellCreditLimit(State storage state, SellCreditLimitParams calldata params) external {
        state.data.users[msg.sender].borrowOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});
        emit Events.SellCreditLimit(
            params.maxDueDate,
            params.curveRelativeTime.tenors,
            params.curveRelativeTime.aprs,
            params.curveRelativeTime.marketRateMultipliers
        );
    }
}
