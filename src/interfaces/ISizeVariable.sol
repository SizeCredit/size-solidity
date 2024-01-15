// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";

interface ISizeVariable {
    function borrowVariable(BorrowVariableParams calldata params) external;
    function repayVariable(RepayVariableParams calldata params) external;
}
