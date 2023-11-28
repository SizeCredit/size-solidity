// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract WithdrawTest is BaseTest {
    function test_SizeWithdraw_withdraw_decreases_user_balance() public {
        vm.startPrank(alice);

        size.deposit(address(usdc), 12);
        size.deposit(address(weth), 23);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 12);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 23);
        assertEq(aliceUser.collateralAsset.locked, 0);

        size.withdraw(address(usdc), 9);
        size.withdraw(address(weth), 7);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 3);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 16);
        assertEq(aliceUser.collateralAsset.locked, 0);
    }

    function test_SizeWithdraw_withdraw_decreases_user_balance(uint256 x, uint256 y, uint256 z, uint256 w) public {
        vm.assume(x > 0 && y > 0);
        vm.startPrank(alice);

        size.deposit(address(usdc), x);
        size.deposit(address(weth), y);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, y);
        assertEq(aliceUser.collateralAsset.locked, 0);

        z = bound(z, 0, x);
        w = bound(w, 0, y);

        vm.assume(z > 0 && w > 0);

        size.withdraw(address(usdc), z);
        size.withdraw(address(weth), w);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x - z);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, y - w);
        assertEq(aliceUser.collateralAsset.locked, 0);
    }

    // function test_SizeWithdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
    // }
}
