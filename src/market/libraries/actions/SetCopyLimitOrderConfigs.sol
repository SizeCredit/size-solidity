// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, UserCopyLimitOrderConfigs} from "@src/market/SizeStorage.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {CopyLimitOrderConfig, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

struct SetCopyLimitOrderConfigsParams {
    // the loan offer copy config parameters
    CopyLimitOrderConfig copyLoanOfferConfig;
    // the borrow offer copy config parameters
    CopyLimitOrderConfig copyBorrowOfferConfig;
}

struct SetCopyLimitOrderConfigsOnBehalfOfParams {
    // the parameters for the copy limit order configs
    SetCopyLimitOrderConfigsParams params;
    // the address to perform the copy on behalf of
    address onBehalfOf;
}

/// @title SetCopyLimitOrderConfigs
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for setting copy limit order configs
library SetCopyLimitOrderConfigs {
    using OfferLibrary for CopyLimitOrderConfig;

    /// @notice Validates the input parameters for setting copy limit order configs
    /// @param externalParams The input parameters for setting copy limit order configs
    /// @dev Does not validate against riskConfig.minTenor or riskConfig.maxTenor since these are already enforced during limit order creation
    function validateSetCopyLimitOrderConfigs(
        State storage state,
        SetCopyLimitOrderConfigsOnBehalfOfParams memory externalParams
    ) external view {
        SetCopyLimitOrderConfigsParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.SET_COPY_LIMIT_ORDER_CONFIGS)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.SET_COPY_LIMIT_ORDER_CONFIGS));
        }

        // validate copyLoanOfferConfig and copyBorrowOfferConfig
        OfferLibrary.validateCopyLimitOrderConfigs(params.copyLoanOfferConfig, params.copyBorrowOfferConfig);
    }

    /// @notice Executes the setting of copy limit order configs
    /// @param state The state
    /// @param externalParams The input parameters for setting copy limit order configs
    function executeSetCopyLimitOrderConfigs(
        State storage state,
        SetCopyLimitOrderConfigsOnBehalfOfParams memory externalParams
    ) external {
        SetCopyLimitOrderConfigsParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        emit Events.SetCopyLimitOrderConfigs(
            msg.sender,
            onBehalfOf,
            params.copyLoanOfferConfig.minTenor,
            params.copyLoanOfferConfig.maxTenor,
            params.copyLoanOfferConfig.minAPR,
            params.copyLoanOfferConfig.maxAPR,
            params.copyLoanOfferConfig.offsetAPR,
            params.copyBorrowOfferConfig.minTenor,
            params.copyBorrowOfferConfig.maxTenor,
            params.copyBorrowOfferConfig.minAPR,
            params.copyBorrowOfferConfig.maxAPR,
            params.copyBorrowOfferConfig.offsetAPR
        );

        state.data.usersCopyLimitOrderConfigs[onBehalfOf].copyLoanOfferConfig = params.copyLoanOfferConfig;
        state.data.usersCopyLimitOrderConfigs[onBehalfOf].copyBorrowOfferConfig = params.copyBorrowOfferConfig;
    }
}
