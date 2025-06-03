// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/market/SizeStorage.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

struct SetVaultParams {
    // the user vault to deposit borrow tokens into
    address vault;
    // Whether to forfeit old shares
    bool forfeitOldShares;
}

struct SetVaultOnBehalfOfParams {
    // The input parameters for setting user configuration
    SetVaultParams params;
    // The address of the account to set user configuration for
    address onBehalfOf;
}

/// @title SetVault
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library SetVault {
    /// @notice Validates the input parameters for setting vault
    /// @param state The state
    /// @param externalParams The input parameters for setting vault
    function validateSetVault(State storage state, SetVaultOnBehalfOfParams memory externalParams) external view {
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.SET_VAULT)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.SET_VAULT));
        }

        // validate vault
        // N/A

        // validate forfeitOldShares
        // N/A
    }

    /// @notice Executes the setting of vault
    /// @param state The state
    /// @param externalParams The input parameters for setting vault
    function executeSetVault(State storage state, SetVaultOnBehalfOfParams memory externalParams) external {
        SetVaultParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        state.data.borrowTokenVault.setVault(onBehalfOf, params.vault, params.forfeitOldShares);

        emit Events.SetVault(msg.sender, onBehalfOf, params.vault, params.forfeitOldShares);
    }
}
