// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {WithdrawVariableParams} from "@src/libraries/variable/actions/WithdrawVariable.sol";
import {BaseTest} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract WithdrawVariableValidationTest is BaseTest {
    function test_WithdrawVariable_validation() public {
        _depositVariable(alice, address(usdc), 1e6);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.withdrawVariable(WithdrawVariableParams({token: address(0), amount: 1}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.withdrawVariable(WithdrawVariableParams({token: address(weth), amount: 0}));
    }
}
