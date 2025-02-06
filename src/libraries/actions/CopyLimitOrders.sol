// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State, UserCopyLimitOrders} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CopyLimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

struct CopyLimitOrdersParams {
    // the address to copy the limit orders from
    address copyAddress;
    // the loan offer copy parameters (null means no copy)
    CopyLimitOrder copyLoanOffer;
    // the borrow offer copy parameters (null means no copy)
    CopyLimitOrder copyBorrowOffer;
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
    /// @param params The input parameters for copying limit orders
    /// @dev Does not validate against riskConfig.minTenor or riskConfig.maxTenor since these are already enforced during limit order creation
    function validateCopyLimitOrders(State storage, CopyLimitOrdersParams calldata params) external pure {
        // validate msg.sender
        // N/A

        bool bothNull = true;

        // validate copyLoanOffer
        if (!params.copyLoanOffer.isNull()) {
            bothNull = false;
            // validate copyLoanOffer.minTenor
            // validate copyLoanOffer.maxTenor
            if (params.copyLoanOffer.minTenor > params.copyLoanOffer.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(params.copyLoanOffer.minTenor, params.copyLoanOffer.maxTenor);
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
        }

        // validate copyAddress
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
    /// @param params The input parameters for copying limit orders
    function executeCopyLimitOrders(State storage state, CopyLimitOrdersParams calldata params) external {
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

        state.data.usersCopyLimitOrders[msg.sender] = UserCopyLimitOrders({
            copyAddress: params.copyAddress,
            copyLoanOffer: params.copyLoanOffer,
            copyBorrowOffer: params.copyBorrowOffer
        });
    }
}
