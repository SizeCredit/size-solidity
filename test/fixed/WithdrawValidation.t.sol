// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneric.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract WithdrawValidationTest is BaseTest {
    function test_Withdraw_validation() public {
        _deposit(alice, address(usdc), 1e6);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.withdraw(WithdrawParams({token: address(0), amount: 1}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.withdraw(WithdrawParams({token: address(weth), amount: 0}));
    }
}