// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UserView} from "@src/SizeView.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract DepositVariableTest is BaseTest {
    function test_DepositVariable_depositVariable_increases_user_balance() public {
        _depositVariable(alice, address(usdc), 1e6);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, 1e18);
        assertEq(aliceUser.variableCollateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), 1e6);

        _depositVariable(alice, address(weth), 2e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, 1e18);
        assertEq(aliceUser.variableCollateralAmount, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function test_DepositVariable_depositVariable_increases_user_balance_pass_time() public {
        _depositVariable(alice, address(usdc), 1e6);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, 1e18);
        assertEq(aliceUser.variableCollateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), 1e6);

        vm.warp(block.timestamp + 1 days);
        aliceUser = size.getUserView(alice);
        assertGt(aliceUser.scaledBorrowAmount, 1e18);
        assertEq(aliceUser.variableCollateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), 1e6);
        uint256 scaledBorrowAmount = aliceUser.scaledBorrowAmount;

        _depositVariable(alice, address(weth), 2e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, scaledBorrowAmount);
        assertEq(aliceUser.variableCollateralAmount, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
        scaledBorrowAmount = aliceUser.scaledBorrowAmount;

        vm.warp(block.timestamp + 1 days);
        aliceUser = size.getUserView(alice);
        assertGt(aliceUser.scaledBorrowAmount, scaledBorrowAmount);
        assertEq(aliceUser.variableCollateralAmount, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function testFuzz_DepositVariable_depositVariable_increases_user_balance2(uint256 x, uint256 y) public {
        x = bound(x, 1, type(uint96).max);
        y = bound(y, 1, type(uint96).max);

        _depositVariable(alice, address(usdc), x);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.variableCollateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), x);

        _depositVariable(alice, address(weth), y);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.variableCollateralAmount, y * 10 ** (18 - weth.decimals()));
        assertEq(weth.balanceOf(address(size)), y);
    }

    function testFuzz_DepositVariable_depositVariable_increases_user_balance_pass_time(
        uint256 x,
        uint256 y,
        uint256 interval
    ) public {
        x = bound(x, 1, type(uint96).max);
        y = bound(y, 1, type(uint96).max);
        interval = bound(interval, 1, 6 * 365 days);

        _depositVariable(alice, address(usdc), x);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.variableCollateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), x);
        uint256 scaledBorrowAmount = aliceUser.scaledBorrowAmount;

        vm.warp(block.timestamp + interval);
        aliceUser = size.getUserView(alice);
        assertGt(aliceUser.scaledBorrowAmount, scaledBorrowAmount);
        assertEq(aliceUser.variableCollateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), x);
        scaledBorrowAmount = aliceUser.scaledBorrowAmount;

        _depositVariable(alice, address(weth), y);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.scaledBorrowAmount, scaledBorrowAmount);
        assertEq(aliceUser.variableCollateralAmount, y * 10 ** (18 - weth.decimals()));
        assertEq(weth.balanceOf(address(size)), y);
        scaledBorrowAmount = aliceUser.scaledBorrowAmount;

        vm.warp(block.timestamp + interval);
        aliceUser = size.getUserView(alice);
        assertGt(aliceUser.scaledBorrowAmount, scaledBorrowAmount);
        assertEq(aliceUser.variableCollateralAmount, y * 10 ** (18 - weth.decimals()));
        assertEq(weth.balanceOf(address(size)), y);
    }
}
