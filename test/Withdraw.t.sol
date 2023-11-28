// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract WithdrawTest is BaseTest {
    function test_SizeWithdraw_withdraw_decreases_user_balance() public {
        _deposit(alice, address(usdc), 12e6);
        _deposit(alice, address(weth), 23e18);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 12e18);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 23e18);
        assertEq(aliceUser.collateralAsset.locked, 0);

        _withdraw(alice, address(usdc), 9e6);
        _withdraw(alice, address(weth), 7e18);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 3e18);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 16e18);
        assertEq(aliceUser.collateralAsset.locked, 0);
    }

    function test_SizeWithdraw_withdraw_decreases_user_balance(uint256 x, uint256 y, uint256 z, uint256 w) public {
        x = bound(x, 1, type(uint128).max);
        y = bound(y, 1, type(uint128).max);
        z = bound(z, 1, type(uint128).max);
        w = bound(w, 1, type(uint128).max);

        _deposit(alice, address(usdc), x * 1e6);
        _deposit(alice, address(weth), y * 1e18);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x * 1e18);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, y * 1e18);
        assertEq(aliceUser.collateralAsset.locked, 0);

        z = bound(z, 1, x);
        w = bound(w, 1, y);

        _withdraw(alice, address(usdc), z * 1e6);
        _withdraw(alice, address(weth), w * 1e18);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, (x - z) * 1e18);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, (y - w) * 1e18);
        assertEq(aliceUser.collateralAsset.locked, 0);
    }

    // function test_SizeWithdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
    // }
}
