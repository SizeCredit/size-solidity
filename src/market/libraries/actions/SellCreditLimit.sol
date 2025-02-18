// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/market/SizeStorage.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";

struct SellCreditLimitParams {
    // The maximum due date of the borrow offer
    uint256 maxDueDate;
    // The yield curve of the borrow offer
    YieldCurve curveRelativeTime;
}

struct SellCreditLimitOnBehalfOfParams {
    // The parameters for the sell credit limit
    SellCreditLimitParams params;
    // The account to set the sell credit limit order for
    address onBehalfOf;
}

/// @title SellCreditLimit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for selling credit (borrowing) as a limit order
library SellCreditLimit {
    using OfferLibrary for LimitOrder;

    /// @notice Validates the input parameters for selling credit as a limit order
    /// @param state The state
    /// @param externalParams The input parameters for selling credit as a limit order
    function validateSellCreditLimit(State storage state, SellCreditLimitOnBehalfOfParams memory externalParams)
        external
        view
    {
        SellCreditLimitParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        LimitOrder memory borrowOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.SELL_CREDIT_LIMIT)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(uint8(Action.SELL_CREDIT_LIMIT)));
        }

        // a null offer mean clearing their limit order
        if (!borrowOffer.isNull()) {
            // validate borrowOffer
            borrowOffer.validateLimitOrder(state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }
    }

    /// @notice Executes the selling of credit as a limit order
    /// @param state The state
    /// @param externalParams The input parameters for selling credit as a limit order
    /// @dev A null offer means clearing a user's borrow limit order
    function executeSellCreditLimit(State storage state, SellCreditLimitOnBehalfOfParams memory externalParams)
        external
    {
        SellCreditLimitParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        emit Events.SellCreditLimit(
            msg.sender,
            params.maxDueDate,
            params.curveRelativeTime.tenors,
            params.curveRelativeTime.aprs,
            params.curveRelativeTime.marketRateMultipliers
        );
        emit Events.OnBehalfOfParams(msg.sender, onBehalfOf, uint8(Action.SELL_CREDIT_LIMIT), address(0));

        state.data.users[onBehalfOf].borrowOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});
    }
}
