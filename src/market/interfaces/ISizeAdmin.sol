// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UpdateConfigParams} from "@src/market/libraries/actions/UpdateConfig.sol";

/// @title ISizeAdmin
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for admin acitons
interface ISizeAdmin {
    /// @notice Updates the configuration of the protocol
    ///         Only callable by the DEFAULT_ADMIN_ROLE
    /// @dev For `address` parameters, the `value` is converted to `uint160` and then to `address`
    /// @param params UpdateConfigParams struct containing the following fields:
    ///     - string key: The configuration parameter to update
    ///     - uint256 value: The value to update
    function updateConfig(UpdateConfigParams calldata params) external;

    /// @notice Pauses the protocol
    ///         Only callable by the PAUSER_ROLE
    function pause() external;

    /// @notice Unpauses the protocol
    ///         Only callable by the UNPAUSER_ROLE
    function unpause() external;
}
