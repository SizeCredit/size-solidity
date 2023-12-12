// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {UserView} from "@src/libraries/UserLibrary.sol";

contract DepositTest is BaseTest {
    function test_Deposit_deposit_increases_user_balance() public {
        _deposit(alice, address(usdc), 1e6);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, 1e18);
        assertEq(aliceUser.collateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), 1e6);

        _deposit(alice, address(weth), 2e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, 1e18);
        assertEq(aliceUser.collateralAmount, 2e18);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function testFuzz_Deposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        x = bound(x, 1, type(uint128).max);
        y = bound(y, 1, type(uint128).max);

        _deposit(alice, address(usdc), x);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.collateralAmount, 0);
        assertEq(usdc.balanceOf(address(size)), x);

        _deposit(alice, address(weth), y);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.collateralAmount, y * 10 ** (18 - weth.decimals()));
        assertEq(weth.balanceOf(address(size)), y);
    }
}
