// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LendAsMarketOrderValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsMarketOrderValidation() public {
        _setPrice(1e18);
        _deposit(alice, weth, 2 * 150e18);
        _deposit(bob, usdc, 10e6);
        _borrowAsLimitOrder(alice, 200e18, 0, 12);

        uint256 dueDate = block.timestamp;

        vm.startPrank(bob);

        vm.expectRevert();
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: address(0), dueDate: dueDate, amount: 100e18, exactAmountIn: false})
        );

        vm.warp(block.timestamp + 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, dueDate));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: alice, dueDate: dueDate, amount: 100e18, exactAmountIn: false})
        );

        dueDate = block.timestamp;

        vm.expectRevert(abi.encodeWithSelector(Errors.AMOUNT_GREATER_THAN_MAX_AMOUNT.selector, 200e18 + 1, 200e18));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: alice, dueDate: dueDate, amount: 200e18 + 1, exactAmountIn: true})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 10e18, 100e18));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: alice, dueDate: dueDate, amount: 100e18, exactAmountIn: false})
        );
    }
}
