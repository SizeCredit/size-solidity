// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";

import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowVariableValidationTest is BaseTest {
    function test_BorrowVariable_validation() public {
        _depositVariable(alice, usdc, 100e6);
        _depositVariable(bob, weth, 100e18);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.borrowVariable(BorrowVariableParams({amount: 0}));

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.USER_IS_LIQUIDATABLE.selector, alice, 0));
        size.borrowVariable(BorrowVariableParams({amount: 100e18}));

        vm.startPrank(bob);
        size.borrowVariable(BorrowVariableParams({amount: 100e18}));
        assertEq(size.getUserView(bob).variableBorrowAmount, 100e18);
    }
}
