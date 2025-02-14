// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title ISizeViewV1_7
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The view interface for the Size v1.7 authorization system
interface ISizeViewV1_7 {
    /// @notice Check if an action is authorized by the `onBehalfOf` account for the `operator` account to perform
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param operator The operator account
    /// @param action The action
    /// @return The authorization status
    function isAuthorized(address onBehalfOf, address operator, bytes4 action) external view returns (bool);
}
