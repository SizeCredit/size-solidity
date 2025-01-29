// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title ISizeV1_6_1
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.6.1 authorization system
interface ISizeV1_6_1 {
    /// @notice Set the authorization for an action for another `other` account to perform on behalf of the `msg.sender` account
    /// @param other The other account
    /// @param action The action
    /// @param newIsAuthorized The new authorization status
    function setAuthorization(address other, bytes4 action, bool newIsAuthorized) external;
}
