// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {LiquidateVariableParams} from "@src/libraries/variable/actions/LiquidateVariable.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract LiquidateVariableValidationTest is BaseTest {
    function test_LiquidateVariable_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.liquidateVariable(LiquidateVariableParams({amount: 1, borrower: address(0)}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.liquidateVariable(LiquidateVariableParams({amount: 0, borrower: alice}));
    }
}
