// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";
import {BorrowVariable, BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {DepositVariable, DepositVariableParams} from "@src/libraries/variable/actions/DepositVariable.sol";
import {RepayVariable, RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";

import {SizeStorage, State} from "@src/SizeStorage.sol";
import {ISizeVariable} from "@src/interfaces/ISizeVariable.sol";

abstract contract SizeVariable is ISizeVariable, SizeStorage {
    using DepositVariable for State;
    using BorrowVariable for State;
    using RepayVariable for State;
    using VariableLibrary for State;

    /// @inheritdoc ISizeVariable
    function depositVariable(DepositVariableParams calldata params) external override(ISizeVariable) {
        state.validateDepositVariable(params);
        state.executeDepositVariable(params);
    }

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
