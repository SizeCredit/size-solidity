// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title ISizeViewV1_6_1
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The view interface for the Size v1.6.1 authorization system
interface ISizeViewV1_6_1 {
    /// @notice Check if an action is authorized by the `user` account for the `other` account to perform
    /// @param user The user
    /// @param other The other account
    /// @param action The action
    /// @return The authorization status
    function isAuthorized(address user, address other, bytes4 action) external view returns (bool);
}
