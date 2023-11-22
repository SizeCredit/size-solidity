// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract SizeWithdrawTest is BaseTest {
    function test_SizeWithdraw_withdraw_decreases_user_balance() public {
        vm.startPrank(alice);

        size.deposit(12, 23);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.cash.free, 12);
        assertEq(aliceUser.cash.locked, 0);
        assertEq(aliceUser.eth.free, 23);
        assertEq(aliceUser.eth.locked, 0);

        size.withdraw(9, 7);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.cash.free, 3);
        assertEq(aliceUser.cash.locked, 0);
        assertEq(aliceUser.eth.free, 16);
        assertEq(aliceUser.eth.locked, 0);
    }

    function test_SizeWithdraw_withdraw_decreases_user_balance(uint256 x, uint256 y, uint256 z, uint256 w) public {
        vm.assume(x > 0 || y > 0);
        vm.startPrank(alice);

        size.deposit(x, y);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.cash.free, x);
        assertEq(aliceUser.cash.locked, 0);
        assertEq(aliceUser.eth.free, y);
        assertEq(aliceUser.eth.locked, 0);

        z = bound(z, 0, x);
        w = bound(w, 0, y);

        vm.assume(z > 0 || w > 0);

        size.withdraw(z, w);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.cash.free, x - z);
        assertEq(aliceUser.cash.locked, 0);
        assertEq(aliceUser.eth.free, y - w);
        assertEq(aliceUser.eth.locked, 0);
    }

    // function test_SizeWithdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
    // }
}
