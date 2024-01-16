// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {DepositVariableParams} from "@src/libraries/variable/actions/DepositVariable.sol";
import {RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";

interface ISizeVariable {
    function depositVariable(DepositVariableParams calldata params) external;
    function borrowVariable(BorrowVariableParams calldata params) external;
    function repayVariable(RepayVariableParams calldata params) external;
}
