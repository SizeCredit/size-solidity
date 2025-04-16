// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Vault} from "@src/market/token/Vault.sol";

/// @title ISizeV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.8 authorization system
interface ISizeV1_8 {
    /// @notice Reinitialize the size contract
    /// @dev This function is only callable by the owner of the contract
    /// @param defaultVault The default vault
    function reinitialize(Vault defaultVault) external;
}
