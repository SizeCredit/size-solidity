// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayVariableParams {
    uint256 amount;
}

library RepayVariable {
    using VariableLibrary for State;

    function validateRepayVariable(State storage, RepayVariableParams calldata params) external pure {
        // validte msg.sender
        // N/A

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeRepayVariable(State storage state, RepayVariableParams calldata params) public {
        state.repayVariableLoan(msg.sender, params.amount);
        emit Events.RepayVariable(params.amount);
    }
}
