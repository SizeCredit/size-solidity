// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Authorization} from "@src/libraries/actions/v1.7/Authorization.sol";

struct BuyCreditLimitParams {
    // The maximum due date of the loan offer
    uint256 maxDueDate;
    // The yield curve of the loan offer
    YieldCurve curveRelativeTime;
}

struct BuyCreditLimitOnBehalfOfParams {
    // The parameters for the buy credit limit
    BuyCreditLimitParams params;
    // The account to set the buy credit limit order for
    address onBehalfOf;
}

/// @title BuyCreditLimit
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for buying credit (lending) as a limit order
library BuyCreditLimit {
    using OfferLibrary for LimitOrder;
    using Authorization for State;

    /// @notice Validates the input parameters for buying credit as a limit order
    /// @param state The state
    /// @param externalParams The input parameters for buying credit as a limit order
    function validateBuyCreditLimit(State storage state, BuyCreditLimitOnBehalfOfParams calldata externalParams)
        external
        view
    {
        BuyCreditLimitParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        LimitOrder memory loanOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});

        // validate msg.sender
        if (!state.isOnBehalfOfOrAuthorized(onBehalfOf, ISize.buyCreditLimit.selector)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, ISize.buyCreditLimit.selector);
        }

        // a null offer mean clearing their limit order
        if (!loanOffer.isNull()) {
            // validate loanOffer
            loanOffer.validateLimitOrder(state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }
    }

    /// @notice Executes the buying of credit as a limit order
    /// @param state The state
    /// @param externalParams The input parameters for buying credit as a limit order
    /// @dev A null offer means clearing a user's loan limit order
    function executeBuyCreditLimit(State storage state, BuyCreditLimitOnBehalfOfParams calldata externalParams)
        external
    {
        BuyCreditLimitParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        emit Events.BuyCreditLimit(
            msg.sender,
            params.maxDueDate,
            params.curveRelativeTime.tenors,
            params.curveRelativeTime.aprs,
            params.curveRelativeTime.marketRateMultipliers
        );
        emit Events.OnBehalfOfParams(msg.sender, onBehalfOf, ISize.buyCreditLimit.selector, address(0));

        state.data.users[onBehalfOf].loanOffer =
            LimitOrder({maxDueDate: params.maxDueDate, curveRelativeTime: params.curveRelativeTime});
    }
}
