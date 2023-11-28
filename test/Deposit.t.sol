// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract DepositTest is BaseTest {
    function test_Deposit_deposit_increases_user_balance() public {
        vm.startPrank(alice);

        size.deposit(address(usdc), 1);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 1);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 0);
        assertEq(aliceUser.collateralAsset.locked, 0);

        size.deposit(address(weth), 2);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, 1);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 2);
        assertEq(aliceUser.collateralAsset.locked, 0);
    }

    function test_Deposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        vm.assume(x > 0 && y > 0);
        vm.startPrank(alice);

        size.deposit(address(usdc), x);
        User memory aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, 0);
        assertEq(aliceUser.collateralAsset.locked, 0);

        size.deposit(address(weth), y);
        aliceUser = size.getUser(alice);
        assertEq(aliceUser.borrowAsset.free, x);
        assertEq(aliceUser.borrowAsset.locked, 0);
        assertEq(aliceUser.collateralAsset.free, y);
        assertEq(aliceUser.collateralAsset.locked, 0);
    }
}
