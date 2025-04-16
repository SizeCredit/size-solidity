// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Vault} from "@src/market/token/Vault.sol";

/// @title ISizeFactoryV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory v1.8
interface ISizeFactoryV1_8 {
    /// @notice Check if an address is a registered vault
    /// @param candidate The candidate to check
    /// @return True if the candidate is a registered vault
    function isVault(address candidate) external view returns (bool);

    /// @notice Add a vault to the factory
    /// @param _vault The vault to add
    /// @return existed True if the vault already existed
    function addVault(Vault _vault) external returns (bool existed);

    /// @notice Remove a vault from the factory
    /// @param _vault The vault to remove
    /// @return existed True if the vault already existed
    function removeVault(Vault _vault) external returns (bool existed);
}
