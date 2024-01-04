// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract DepositValidationTest is BaseTest {
    function test_Deposit_validation() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.deposit(DepositParams({token: address(0), amount: 1}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.deposit(DepositParams({token: address(weth), amount: 0}));
    }
}
