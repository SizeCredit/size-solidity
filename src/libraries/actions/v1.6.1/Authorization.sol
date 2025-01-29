// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";

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
    function validateSetAuthorization(State storage, address, bytes4, bool) internal view {
        // N/A
    }

    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param operator The operator account
    /// @param action The action
    /// @param isActionAuthorized The new authorization status
    function executeSetAuthorization(State storage state, address operator, bytes4 action, bool isActionAuthorized)
        internal
    {
        _setAuthorization(state, msg.sender, operator, action, isActionAuthorized);
    }
}
