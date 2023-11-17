// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

contract SizeWithdrawTest is BaseTest {
    function test_SizeWithdraw_withdraw_decreases_user_balance() public {
        vm.startPrank(alice);

        size.deposit(12, 23);
        (uint256 cashFree, uint256 cashLocked, uint256 ethFree, uint256 ethLocked) = size.getUserCollateral(alice);
        assertEq(cashFree, 12);
        assertEq(cashLocked, 0);
        assertEq(ethFree, 23);
        assertEq(ethLocked, 0);

        size.withdraw(9, 7);
        (cashFree, cashLocked, ethFree, ethLocked) = size.getUserCollateral(alice);
        assertEq(cashFree, 3);
        assertEq(cashLocked, 0);
        assertEq(ethFree, 16);
        assertEq(ethLocked, 0);
    }

    function test_SizeWithdraw_withdraw_decreases_user_balance(uint256 x, uint256 y, uint256 z, uint256 w) public {
        vm.startPrank(alice);

        size.deposit(x, y);
        (uint256 cashFree, uint256 cashLocked, uint256 ethFree, uint256 ethLocked) = size.getUserCollateral(alice);
        assertEq(cashFree, x);
        assertEq(cashLocked, 0);
        assertEq(ethFree, y);
        assertEq(ethLocked, 0);

        z = bound(z, 0, x);
        w = bound(w, 0, y);

        size.withdraw(z, w);
        (cashFree, cashLocked, ethFree, ethLocked) = size.getUserCollateral(alice);
        assertEq(cashFree, x - z);
        assertEq(cashLocked, 0);
        assertEq(ethFree, y - w);
        assertEq(ethLocked, 0);
    }

    // function test_SizeWithdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
    // }
}
