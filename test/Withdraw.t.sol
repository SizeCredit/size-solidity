// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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

    function test_SizeWithdraw_deposit_withdraw_identity(uint256 valueUSDC, uint256 valueWETH) public {
        valueUSDC = bound(valueUSDC, 1, type(uint256).max / 1e12);
        valueWETH = bound(valueWETH, 1, type(uint256).max);
        deal(address(usdc), alice, valueUSDC);
        deal(address(weth), alice, valueWETH);

        vm.startPrank(alice);
        IERC20Metadata(usdc).approve(address(size), valueUSDC);
        IERC20Metadata(weth).approve(address(size), valueWETH);

        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), 0);
        assertEq(weth.balanceOf(address(alice)), valueWETH);

        size.deposit(address(usdc), valueUSDC);
        size.deposit(address(weth), valueWETH);

        assertEq(usdc.balanceOf(address(size)), valueUSDC);
        assertEq(usdc.balanceOf(address(alice)), 0);
        assertEq(weth.balanceOf(address(size)), valueWETH);
        assertEq(weth.balanceOf(address(alice)), 0);

        size.withdraw(address(usdc), valueUSDC);
        size.withdraw(address(weth), valueWETH);

        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), 0);
        assertEq(weth.balanceOf(address(alice)), valueWETH);
    }

    // function test_SizeWithdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
    // }
}
