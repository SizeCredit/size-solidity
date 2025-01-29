// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";

/// @title AuthorizationLibrary
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library AuthorizationLibrary {
    /// @notice Set the authorization for an action for another `other` account to perform on behalf of the `user` account
    /// @param state The state struct
    /// @param user The user
    /// @param other The other account
    /// @param action The action
    /// @param newIsAuthorized The new authorization status
    /// @dev Actions are encoded as bytes4 values because all external functions can be uniquely determined by their function selectors
    function _setAuthorization(State storage state, address user, address other, bytes4 action, bool newIsAuthorized)
        private
    {
        emit Events.SetAuthorization(user, other, action, newIsAuthorized);
        state.data.authorizations[user][other][action] = newIsAuthorized;
    }

    /// @notice Check if an action is authorized by the `user` account for the `other` account to perform
    /// @param state The state struct
    /// @param user The user
    /// @param other The other account
    /// @param action The action
    /// @return The authorization status
    function _isAuthorized(State storage state, address user, address other, bytes4 action)
        private
        view
        returns (bool)
    {
        return state.data.authorizations[user][other][action];
    }

    /// @notice Set the authorization for an action for another `other` account to perform on behalf of the `msg.sender` account
    /// @param state The state struct
    /// @param other The other account
    /// @param action The action
    /// @param newIsAuthorized The new authorization status
    function setAuthorization(State storage state, address other, bytes4 action, bool newIsAuthorized) internal {
        _setAuthorization(state, msg.sender, other, action, newIsAuthorized);
    }

    /// @notice Check if an action is authorized by the `user` account for the `msg.sender` account to perform
    /// @param state The state struct
    /// @param user The user
    /// @param action The action
    /// @return The authorization status
    function isAuthorized(State storage state, address user, bytes4 action) internal view returns (bool) {
        return _isAuthorized(state, user, msg.sender, action);
    }

    /// @notice Check if the `user` account is the `msg.sender` account or if `msg.sender` is authorized to perform the `action` on behalf of the `user` account
    /// @param state The state struct
    /// @param user The user
    /// @param action The action
    /// @return The authorization status
    function isUserOrAuthorized(State storage state, address user, bytes4 action) internal view returns (bool) {
        return msg.sender == user || isAuthorized(state, user, action);
    }
}
