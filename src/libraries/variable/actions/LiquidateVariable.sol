// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct LiquidateVariableParams {
    address borrower;
    uint256 amount;
}

library LiquidateVariable {
    using VariableLibrary for State;

    function validateLiquidateVariable(State storage, LiquidateVariableParams calldata params) external pure {
        // validte msg.sender
        // N/A

        // validate borrower
        if (params.borrower == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeLiquidateVariable(State storage state, LiquidateVariableParams calldata params) public {
        state.liquidateVariableLoan(msg.sender, params.borrower, params.amount);
        emit Events.LiquidateVariable(params.borrower, params.amount);
    }
}
