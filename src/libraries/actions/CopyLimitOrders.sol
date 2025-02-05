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
library CopyLimitOrders {
    using OfferLibrary for CopyLimitOrder;

    /// @notice Validates the input parameters for copying limit orders
    /// @param state The state
    /// @param params The input parameters for copying limit orders
    function validateCopyLimitOrders(State storage state, CopyLimitOrdersParams calldata params) external view {
        // validate msg.sender
        // N/A

        bool bothNull = true;

        // validate copyLoanOffer
        if (!params.copyLoanOffer.isNull()) {
            bothNull = false;
            // validate copyLoanOffer.minTenor
            if (params.copyLoanOffer.minTenor < state.riskConfig.minTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(
                    params.copyLoanOffer.minTenor, state.riskConfig.minTenor, state.riskConfig.maxTenor
                );
            }

            // validate copyLoanOffer.maxTenor
            if (params.copyLoanOffer.maxTenor > state.riskConfig.maxTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(
                    params.copyLoanOffer.maxTenor, state.riskConfig.minTenor, state.riskConfig.maxTenor
                );
            }

            if (params.copyLoanOffer.minTenor > params.copyLoanOffer.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(params.copyLoanOffer.minTenor, params.copyLoanOffer.maxTenor);
            }
        }

        // validate copyBorrowOffer
        if (!params.copyBorrowOffer.isNull()) {
            bothNull = false;
            // validate copyBorrowOffer.minTenor
            if (params.copyBorrowOffer.minTenor < state.riskConfig.minTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(
                    params.copyBorrowOffer.minTenor, state.riskConfig.minTenor, state.riskConfig.maxTenor
                );
            }

            // validate copyBorrowOffer.maxTenor
            if (params.copyBorrowOffer.maxTenor > state.riskConfig.maxTenor) {
                revert Errors.TENOR_OUT_OF_RANGE(
                    params.copyBorrowOffer.maxTenor, state.riskConfig.minTenor, state.riskConfig.maxTenor
                );
            }

            if (params.copyBorrowOffer.minTenor > params.copyBorrowOffer.maxTenor) {
                revert Errors.INVALID_TENOR_RANGE(params.copyBorrowOffer.minTenor, params.copyBorrowOffer.maxTenor);
            }
        }

        // validate copyAddress
        if (bothNull) {
            if (params.copyAddress == address(0)) {
                revert Errors.NULL_ADDRESS();
            } else {
                revert Errors.INVALID_ADDRESS(params.copyAddress);
            }
        }
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
            params.copyBorrowOffer.minTenor,
            params.copyBorrowOffer.maxTenor,
            params.copyBorrowOffer.minAPR,
            params.copyBorrowOffer.maxAPR
        );

        state.data.usersCopyLimitOrders[msg.sender] = UserCopyLimitOrders({
            copyAddress: params.copyAddress,
            copyLoanOffer: params.copyLoanOffer,
            copyBorrowOffer: params.copyBorrowOffer
        });
    }
}
