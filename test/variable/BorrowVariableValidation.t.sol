// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {BorrowVariableParams} from "@src/libraries/variable/actions/BorrowVariable.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract BorrowVariableValidationTest is BaseTest {
    function test_BorrowVariable_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.borrowVariable(BorrowVariableParams({amount: 1, to: address(0)}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.borrowVariable(BorrowVariableParams({amount: 0, to: alice}));
    }
}
