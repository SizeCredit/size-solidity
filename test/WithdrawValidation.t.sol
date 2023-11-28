// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";

import {Error} from "@src/libraries/Error.sol";

contract WithdrawValidationTest is BaseTest {
    function test_WithdrawValidation() public {
        _deposit(alice, address(usdc), 1e6);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Error.INVALID_TOKEN.selector, address(0)));
        size.withdraw(address(0), 1);

        vm.expectRevert(abi.encodeWithSelector(Error.NULL_AMOUNT.selector));
        size.withdraw(address(weth), 0);
    }
}
