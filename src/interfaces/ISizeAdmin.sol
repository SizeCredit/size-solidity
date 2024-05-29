// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";

/// @title ISizeAdmin
/// @notice The interface for admin acitons
interface ISizeAdmin {
    /// @notice Updates the configuration of the protocol
    ///         Only callabe by the DEFAULT_ADMIN_ROLE
    /// @dev For `address` parameters, the `value` is converted to `uint160` and then to `address`
    /// @param params UpdateConfigParams struct containing the following fields:
    ///     - string key: The configuration parameter to update
    ///     - uint256 value: The value to update
    function updateConfig(UpdateConfigParams calldata params) external;

    /// @notice Sets the variable borrow rate
    ///         Only callabe by the BORROW_RATE_UPDATER_ROLE
    /// @dev The variable pool borrow rate cannot be used if the variablePoolBorrowRateStaleRateInterval is set to zero
    /// @param borrowRate The new borrow rate
    function setVariablePoolBorrowRate(uint128 borrowRate) external;

    /// @notice Pauses the protocol
    ///         Only callabe by the DEFAULT_ADMIN_ROLE
    function pause() external;

    /// @notice Unpauses the protocol
    ///         Only callabe by the DEFAULT_ADMIN_ROLE
    function unpause() external;
}
