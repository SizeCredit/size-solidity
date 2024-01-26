// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract DepositValidationTest is BaseTest {
    function test_Deposit_validation() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TOKEN.selector, address(0)));
        size.deposit(DepositParams({token: address(0), amount: 1, to: alice}));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.deposit(DepositParams({token: address(weth), amount: 0, to: alice}));
    }
}
