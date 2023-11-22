// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract SizeDepositTest is BaseTest {
    function test_SizeDeposit_deposit_increases_user_balance() public {
        vm.startPrank(alice);

        size.deposit(1, 2);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.cash.free, 1);
        assertEq(aliceUser.cash.locked, 0);
        assertEq(aliceUser.eth.free, 2);
        assertEq(aliceUser.eth.locked, 0);
    }

    function test_SizeDeposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        vm.assume(x > 0 || y > 0);
        vm.startPrank(alice);

        size.deposit(x, y);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.cash.free, x);
        assertEq(aliceUser.cash.locked, 0);
        assertEq(aliceUser.eth.free, y);
        assertEq(aliceUser.eth.locked, 0);
    }
}
