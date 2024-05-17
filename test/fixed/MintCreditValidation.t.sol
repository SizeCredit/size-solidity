// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {MintCreditParams} from "@src/libraries/fixed/actions/MintCredit.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract MintCreditValidationTest is BaseTest {
    function test_MintCredit_validation() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 42 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        _mintCredit(bob, 100e6, block.timestamp + 365 days);

        uint256 dueDate = block.timestamp - 1;

        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(size.mintCredit, MintCreditParams({amount: 100e6, dueDate: dueDate}));
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, dueDate));
        size.multicall(data);
    }
}
