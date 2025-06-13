// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SetVaultParams} from "@src/market/libraries/actions/SetVault.sol";
import {SetVaultOnBehalfOfParams} from "@src/market/libraries/actions/SetVault.sol";

/// @title ISizeV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the Size v1.8 view methods
interface ISizeV1_8 {
    /// @notice Reinitialize the contract
    /// @dev Initializes the reentrancy guard
    function reinitialize() external;

    /// @notice Set the vault for a user
    /// @param params SetVaultParams struct containing the following fields:
    ///     - address vault: The address of the vault to set
    ///     - bool forfeitOldShares: Whether to forfeit old shares. WARNING: This will reset the user's balance to 0.
    function setVault(SetVaultParams calldata params) external payable;

    /// @notice Set the vault for a user on behalf of another user
    /// @param params SetVaultOnBehalfOfParams struct containing the following fields:
    ///     - address onBehalfOf: The address of the user to set the vault for
    ///     - address vault: The address of the vault to set
    ///     - bool forfeitOldShares: Whether to forfeit old shares. WARNING: This will reset the user's balance to 0.
    function setVaultOnBehalfOf(SetVaultOnBehalfOfParams calldata params) external payable;
}
