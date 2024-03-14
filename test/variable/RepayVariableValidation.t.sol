// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {RepayVariableParams} from "@src/libraries/variable/actions/RepayVariable.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract RepayVariableValidationTest is BaseTest {
    function test_RepayVariable_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.repayVariable(RepayVariableParams({amount: 0}));
    }
}
