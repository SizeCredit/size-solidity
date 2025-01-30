// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SetAuthorizationParams {
    address operator;
    bytes4 action;
    bool isActionAuthorized;
}

struct SetAuthorizationOnBehalfOfParams {
    SetAuthorizationParams params;
    address onBehalfOf;
}

/// @title Authorization
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library Authorization {
    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `onBehalfOf` account
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param operator The operator account
    /// @param action The action
    /// @param isActionAuthorized The new authorization status
    function _setAuthorization(
        State storage state,
        address onBehalfOf,
        address operator,
        bytes4 action,
        bool isActionAuthorized
    ) private {
        emit Events.SetAuthorization(onBehalfOf, operator, action, isActionAuthorized);
        state.data.authorizations[onBehalfOf][operator][action] = isActionAuthorized;
    }

    /// @notice Check if an action is authorized by the `onBehalfOf` account for the `operator` account to perform
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param operator The operator account
    /// @param action The action
    /// @return The authorization status
    function isAuthorized(State storage state, address onBehalfOf, address operator, bytes4 action)
        internal
        view
        returns (bool)
    {
        return state.data.authorizations[onBehalfOf][operator][action];
    }

    /// @notice Check if the `onBehalfOf` account is the `msg.sender` account or if `msg.sender` is the operator authorized to perform the `action`
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param action The action
    /// @return The authorization status
    function isOnBehalfOfOrAuthorized(State storage state, address onBehalfOf, bytes4 action)
        internal
        view
        returns (bool)
    {
        return msg.sender == onBehalfOf || isAuthorized(state, onBehalfOf, msg.sender, action);
    }

    /// @notice Validate the input parameters for setting the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param externalParams The input parameters for setting the authorization
    function validateSetAuthorization(State storage state, SetAuthorizationOnBehalfOfParams memory externalParams)
        internal
        view
    {
        SetAuthorizationParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!isOnBehalfOfOrAuthorized(state, onBehalfOf, ISizeV1_7.setAuthorization.selector)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, ISizeV1_7.setAuthorization.selector);
        }

        // validate operator
        if (params.operator == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate action
        if (
            !(
                params.action == ISize.deposit.selector || params.action == ISize.withdraw.selector
                    || params.action == ISize.buyCreditLimit.selector || params.action == ISize.sellCreditLimit.selector
                    || params.action == ISize.buyCreditMarket.selector || params.action == ISize.sellCreditMarket.selector
                    || params.action == ISize.selfLiquidate.selector || params.action == ISize.compensate.selector
                    || params.action == ISize.setUserConfiguration.selector
                    || params.action == ISizeV1_7.setAuthorization.selector
            )
        ) {
            revert Errors.INVALID_ACTION(params.action);
        }

        // validate isActionAuthorized
        // N/A
    }

    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param externalParams The input parameters for setting the authorization
    function executeSetAuthorization(State storage state, SetAuthorizationOnBehalfOfParams memory externalParams)
        internal
    {
        SetAuthorizationParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;
        _setAuthorization(state, onBehalfOf, params.operator, params.action, params.isActionAuthorized);
    }
}
