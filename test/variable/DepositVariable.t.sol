// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UserView} from "@src/SizeView.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract DepositVariableTest is BaseTest {
    function test_DepositVariable_deposit_increases_user_balance() public {
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

    function testFuzz_DepositVariable_deposit_increases_user_balance(uint256 x, uint256 y) public {
        x = bound(x, 1, type(uint128).max);
        y = bound(y, 1, type(uint128).max);

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
}
