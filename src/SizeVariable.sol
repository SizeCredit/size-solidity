// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";
import {BorrowVariable, BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {RepayVariable, RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";

import {SizeStorage, State} from "@src/SizeStorage.sol";
import {ISizeVariable} from "@src/interfaces/ISizeVariable.sol";

abstract contract SizeVariable is ISizeVariable, SizeStorage {
    using BorrowVariable for State;
    using RepayVariable for State;
    using VariablePoolLibrary for State;

    /// @inheritdoc ISizeVariable
    function borrowVariable(BorrowVariableParams calldata params) external override(ISizeVariable) {
        state.validateBorrowVariable(params);
        state.executeBorrowVariable(params);
        state.validateUserIsNotLiquidatableVariable(msg.sender);
    }

    /// @inheritdoc ISizeVariable
    function repayVariable(RepayVariableParams calldata params) external override(ISizeVariable) {
        state.validateRepayVariable(params);
        state.executeRepayVariable(params);
    }
}
