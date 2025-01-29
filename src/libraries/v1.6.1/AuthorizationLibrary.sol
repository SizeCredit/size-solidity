// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";

/// @title AuthorizationLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library AuthorizationLibrary {
    /// @notice Set the authorization for an action for another `other` account to perform on behalf of the `onBehalfOf` account
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param other The other account
    /// @param action The action
    /// @param isActionAuthorized The new authorization status
    function _setAuthorization(
        State storage state,
        address onBehalfOf,
        address other,
        bytes4 action,
        bool isActionAuthorized
    ) private {
        emit Events.SetAuthorization(onBehalfOf, other, action, isActionAuthorized);
        state.data.authorizations[onBehalfOf][other][action] = isActionAuthorized;
    }

    /// @notice Check if an action is authorized by the `onBehalfOf` account for the `other` account to perform
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param other The other account
    /// @param action The action
    /// @return The authorization status
    function _isAuthorized(State storage state, address onBehalfOf, address other, bytes4 action)
        private
        view
        returns (bool)
    {
        return state.data.authorizations[onBehalfOf][other][action];
    }

    /// @notice Set the authorization for an action for another `other` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param other The other account
    /// @param action The action
    /// @param isActionAuthorized The new authorization status
    function setAuthorization(State storage state, address other, bytes4 action, bool isActionAuthorized) internal {
        _setAuthorization(state, msg.sender, other, action, isActionAuthorized);
    }

    /// @notice Check if the `onBehalfOf` account is the `msg.sender` account or if `msg.sender` is authorized to perform the `action` on behalf of the `onBehalfOf` account
    /// @param state The state struct
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param action The action
    /// @return The authorization status
    function isOnBehalfOfOrAuthorized(State storage state, address onBehalfOf, bytes4 action)
        internal
        view
        returns (bool)
    {
        return msg.sender == onBehalfOf || _isAuthorized(state, onBehalfOf, msg.sender, action);
    }
}
