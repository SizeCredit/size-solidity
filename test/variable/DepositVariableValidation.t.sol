// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {DepositVariableParams} from "@src/libraries/variable/actions/DepositVariable.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract DepositVariableValidationTest is BaseTest {
    function test_DepositVariable_validation() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.depositVariable(DepositVariableParams({token: address(0), amount: 1}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.depositVariable(DepositVariableParams({token: address(weth), amount: 0}));
    }
}
