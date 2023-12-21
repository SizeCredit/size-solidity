// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract WithdrawValidationTest is BaseTest {
    function test_WithdrawValidation() public {
        _deposit(alice, address(usdc), 1e6);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.withdraw(WithdrawParams({token: address(0), amount: 1}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.withdraw(WithdrawParams({token: address(weth), amount: 0}));
    }
}
