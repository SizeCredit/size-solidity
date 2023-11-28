// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract DepositTest is BaseTest {
    function test_Deposit_deposit_increases_user_balance() public {
        _deposit(alice, address(usdc), 1e6);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 1e18);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 0);
        assertEq(aliceUser.collateralAsset.locked, 0);
        assertEq(usdc.balanceOf(address(size)), 1e6);

        _deposit(alice, address(weth), 2e18);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 1e18);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 2e18);
        assertEq(aliceUser.collateralAsset.locked, 0);
        assertEq(weth.balanceOf(address(size)), 2e18);
    }

    function test_Deposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        x = bound(x, 1, type(uint128).max);
        y = bound(y, 1, type(uint128).max);

        _deposit(alice, address(usdc), x);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 0);
        assertEq(aliceUser.collateralAsset.locked, 0);
        assertEq(usdc.balanceOf(address(size)), x);

        _deposit(alice, address(weth), y);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x * 10 ** (18 - usdc.decimals()));
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, y * 10 ** (18 - weth.decimals()));
        assertEq(aliceUser.collateralAsset.locked, 0);
        assertEq(weth.balanceOf(address(size)), y);
    }
}
