// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title ISizeV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.8 view methods
interface ISizeV1_8 {
    /// @notice Reinitialize the contract
    /// @dev Initializes the reentrancy guard
    function reinitialize() external;
}
