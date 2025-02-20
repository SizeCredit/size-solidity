// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, UserCopyLimitOrders} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CopyLimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {Action} from "@src/v1.5/libraries/Authorization.sol";

struct CopyLimitOrdersParams {
    // the address to copy the limit orders from
    address copyAddress;
    // the loan offer copy parameters (null means no copy)
    CopyLimitOrder copyLoanOffer;
    // the borrow offer copy parameters (null means no copy)
    CopyLimitOrder copyBorrowOffer;
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
/// @dev Invariants:
///      - copyAddress != address(0) <=> at least one of copyLoanOffer or copyBorrowOffer is non-null
///      - copyAddress == address(0) <=> both copyLoanOffer and copyBorrowOffer are null
library CopyLimitOrders {
    using OfferLibrary for CopyLimitOrder;

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

        bool bothNull = true;

        // validate copyLoanOffer
        if (!params.copyLoanOffer.isNull()) {
            bothNull = false;
            // validate copyLoanOffer.minTenor
            // validate copyLoanOffer.maxTenor
            if (params.copyLoanOffer.minTenor > params.copyLoanOffer.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(params.copyLoanOffer.minTenor, params.copyLoanOffer.maxTenor);
            }

            // validate copyLoanOffer.minAPR
            // validate copyLoanOffer.maxAPR
            if (params.copyLoanOffer.minAPR > params.copyLoanOffer.maxAPR) {
                revert Errors.INVALID_APR_RANGE(params.copyLoanOffer.minAPR, params.copyLoanOffer.maxAPR);
            }
        }

        // validate copyBorrowOffer
        if (!params.copyBorrowOffer.isNull()) {
            bothNull = false;
            // validate copyBorrowOffer.minTenor
            // validate copyBorrowOffer.maxTenor
            if (params.copyBorrowOffer.minTenor > params.copyBorrowOffer.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(params.copyBorrowOffer.minTenor, params.copyBorrowOffer.maxTenor);
            }

            // validate copyBorrowOffer.minAPR
            // validate copyBorrowOffer.maxAPR
            if (params.copyBorrowOffer.minAPR > params.copyBorrowOffer.maxAPR) {
                revert Errors.INVALID_APR_RANGE(params.copyBorrowOffer.minAPR, params.copyBorrowOffer.maxAPR);
            }
        }

        // validate copyAddress
        if (params.copyAddress == onBehalfOf) {
            revert Errors.INVALID_ADDRESS(params.copyAddress);
        }

        if (bothNull) {
            // both offers are null, so copyAddress must be address(0)
            if (params.copyAddress != address(0)) {
                revert Errors.INVALID_ADDRESS(params.copyAddress);
            }
        } else {
            // at least one offer is non-null, so copyAddress must be non-zero
            if (params.copyAddress == address(0)) {
                revert Errors.NULL_ADDRESS();
            }
        }

        // validate copyLoanOffer.offsetAPR
        // N/A

        // validate copyBorrowOffer.offsetAPR
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
            params.copyAddress,
            params.copyLoanOffer.minTenor,
            params.copyLoanOffer.maxTenor,
            params.copyLoanOffer.minAPR,
            params.copyLoanOffer.maxAPR,
            params.copyLoanOffer.offsetAPR,
            params.copyBorrowOffer.minTenor,
            params.copyBorrowOffer.maxTenor,
            params.copyBorrowOffer.minAPR,
            params.copyBorrowOffer.maxAPR,
            params.copyBorrowOffer.offsetAPR
        );
        emit Events.OnBehalfOfParams(msg.sender, onBehalfOf, uint8(Action.COPY_LIMIT_ORDERS), address(0));

        state.data.usersCopyLimitOrders[onBehalfOf] = UserCopyLimitOrders({
            copyAddress: params.copyAddress,
            copyLoanOffer: params.copyLoanOffer,
            copyBorrowOffer: params.copyBorrowOffer
        });
    }
}
