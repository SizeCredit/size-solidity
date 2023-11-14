// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

contract SizeDepositTest is BaseTest {
    function test_SizeDeposit_deposit_increases_user_balance() public {
        vm.startPrank(alice);

        size.deposit(1, 2);
        (uint256 cashFree, uint256 cashLocked, uint256 ethFree, uint256 ethLocked) = size.getUserCollateral(alice);
        assertEq(cashFree, 1);
        assertEq(cashLocked, 0);
        assertEq(ethFree, 2);
        assertEq(ethLocked, 0);
    }

    function test_SizeDeposit_deposit_increases_user_balance(uint256 x, uint256 y) public {
        vm.startPrank(alice);

        size.deposit(x, y);
        (uint256 cashFree, uint256 cashLocked, uint256 ethFree, uint256 ethLocked) = size.getUserCollateral(alice);
        assertEq(cashFree, x);
        assertEq(cashLocked, 0);
        assertEq(ethFree, y);
        assertEq(ethLocked, 0);
    }
}
