// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";

/// @title ISizeViewV1_7
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.7 view methods
interface ISizeViewV1_7 {
    /// @notice Get the size factory
    /// @return The size factory
    function sizeFactory() external view returns (ISizeFactory);
}
