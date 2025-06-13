// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Action, ActionsBitmap} from "@src/factory/libraries/Authorization.sol";

/// @title ISizeFactoryV1_7
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory v1.7
interface ISizeFactoryV1_7 {
    /// @notice Set the authorization for an action for an `operator` account to perform on behalf of the `msg.sender` account
    /// @param operator The operator account
    /// @param actionsBitmap The actions bitmap
    /// @dev Actions bitmap are encoded a uint256 value because all external actions can fit in a uint256
    ///      To construct the actionsBitmap, the `Authorization.getActionsBitmap` functions can be used
    ///      Not all actions require authorization (for example, `repay`, `liquidate`, etc.)
    ///      In order to possible to authorize/revoke many actions at once, simply construct the actions bitmap using bitmap operations
    ///      For example, to revoke an operator, simply set the authorization bitmap for that operator to `uint256(0)`
    ///      To revoke all authorizations for all operators at once, use `revokeAllAuthorizations`
    ///      Calling this function twice will set the actionsBitmap for the operator with the new value
    function setAuthorization(address operator, ActionsBitmap actionsBitmap) external;

    /// @notice Revoke all authorizations for the `msg.sender` account
    function revokeAllAuthorizations() external;

    /// @notice Check if actions are authorized by the `onBehalfOf` account for the `operator` account to perform
    /// @param operator The operator account
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param action The action
    /// @return The authorization status
    function isAuthorized(address operator, address onBehalfOf, Action action) external view returns (bool);
}
