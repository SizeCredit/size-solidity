// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

import {Error} from "@src/libraries/Error.sol";

contract DepositValidationTest is BaseTest {
    function test_DepositValidation() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_TOKEN.selector, address(0)));
        size.deposit(address(0), 1);

        vm.expectRevert(abi.encodeWithSelector(Error.NULL_AMOUNT.selector));
        size.deposit(address(weth), 0);
    }
}
