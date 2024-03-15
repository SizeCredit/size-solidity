// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct BorrowVariableParams {
    address to;
    uint256 amount;
}

library BorrowVariable {
    using VariableLibrary for State;

    function validateBorrowVariable(State storage, BorrowVariableParams calldata params) external pure {
        // validte msg.sender
        // N/A

        // validate to
        if (params.to == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeBorrowVariable(State storage state, BorrowVariableParams calldata params) public {
        state.borrowVariableLoan(msg.sender, params.to, params.amount);
        emit Events.BorrowVariable(params.to, params.amount);
    }
}
