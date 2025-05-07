// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, UserCopyLimitOrders} from "@src/market/SizeStorage.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {CopyLimitOrderConfig, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

// updated in v1.8, removed `address copyAddress` from params
struct CopyLimitOrdersParams {
    // the loan offer copy parameters
    CopyLimitOrderConfig copyLoanOfferConfig;
    // the borrow offer copy parameters
    CopyLimitOrderConfig copyBorrowOfferConfig;
}

struct CopyLimitOrdersOnBehalfOfParams {
    // the parameters for the copy limit orders
    CopyLimitOrdersParams params;
    // the address to perform the copy on behalf of
    address onBehalfOf;
}

/// @title CopyLimitOrders
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for copying limit orders
library CopyLimitOrders {
    using OfferLibrary for CopyLimitOrderConfig;

    /// @notice Validates the input parameters for copying limit orders
    /// @param externalParams The input parameters for copying limit orders
    /// @dev Does not validate against riskConfig.minTenor or riskConfig.maxTenor since these are already enforced during limit order creation
    function validateCopyLimitOrders(State storage state, CopyLimitOrdersOnBehalfOfParams memory externalParams)
        external
        view
    {
        CopyLimitOrdersParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        // validate msg.sender
        if (!state.data.sizeFactory.isAuthorized(msg.sender, onBehalfOf, Action.COPY_LIMIT_ORDERS)) {
            revert Errors.UNAUTHORIZED_ACTION(msg.sender, onBehalfOf, uint8(Action.COPY_LIMIT_ORDERS));
        }

        // validate copyLoanOfferConfig
        if (!params.copyLoanOfferConfig.isNull()) {
            // validate copyLoanOfferConfig.minTenor
            // validate copyLoanOfferConfig.maxTenor
            if (params.copyLoanOfferConfig.minTenor > params.copyLoanOfferConfig.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(
                    params.copyLoanOfferConfig.minTenor, params.copyLoanOfferConfig.maxTenor
                );
            }

            // validate copyLoanOfferConfig.minAPR
            // validate copyLoanOfferConfig.maxAPR
            if (params.copyLoanOfferConfig.minAPR > params.copyLoanOfferConfig.maxAPR) {
                revert Errors.INVALID_APR_RANGE(params.copyLoanOfferConfig.minAPR, params.copyLoanOfferConfig.maxAPR);
            }
        }

        // validate copyBorrowOfferConfig
        if (!params.copyBorrowOfferConfig.isNull()) {
            // validate copyBorrowOfferConfig.minTenor
            // validate copyBorrowOfferConfig.maxTenor
            if (params.copyBorrowOfferConfig.minTenor > params.copyBorrowOfferConfig.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(
                    params.copyBorrowOfferConfig.minTenor, params.copyBorrowOfferConfig.maxTenor
                );
            }

            // validate copyBorrowOfferConfig.minAPR
            // validate copyBorrowOfferConfig.maxAPR
            if (params.copyBorrowOfferConfig.minAPR > params.copyBorrowOfferConfig.maxAPR) {
                revert Errors.INVALID_APR_RANGE(
                    params.copyBorrowOfferConfig.minAPR, params.copyBorrowOfferConfig.maxAPR
                );
            }
        }

        // validate copyLoanOfferConfig.offsetAPR
        // N/A

        // validate copyBorrowOfferConfig.offsetAPR
        // N/A
    }

    /// @notice Executes the copying of limit orders
    /// @param state The state
    /// @param externalParams The input parameters for copying limit orders
    function executeCopyLimitOrders(State storage state, CopyLimitOrdersOnBehalfOfParams memory externalParams)
        external
    {
        CopyLimitOrdersParams memory params = externalParams.params;
        address onBehalfOf = externalParams.onBehalfOf;

        emit Events.CopyLimitOrders(
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

        state.data.usersCopyLimitOrders[onBehalfOf].copyLoanOfferConfig = params.copyLoanOfferConfig;
        state.data.usersCopyLimitOrders[onBehalfOf].copyBorrowOfferConfig = params.copyBorrowOfferConfig;
    }
}
