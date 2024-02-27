// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LendAsMarketOrderValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsMarketOrder_validation() public {
        _setPrice(1e18);
        _deposit(alice, weth, 2 * 150e18);
        _deposit(bob, usdc, 10e6);
        _borrowAsLimitOrder(alice, [int256(1e18), int256(1e18)], [uint256(365 days), uint256(365 days * 2)]);

        uint256 dueDate = block.timestamp + 365 days;

        vm.startPrank(bob);

        vm.expectRevert();
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: address(0),
                dueDate: dueDate,
                amount: 100e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE.selector, bob, 10e6, 50e6));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: dueDate,
                amount: 100e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, block.timestamp - 1));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp - 1,
                amount: 100e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, block.timestamp - 1));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 365 days,
                amount: 10e6,
                deadline: block.timestamp - 1,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.APR_LOWER_THAN_MIN_APR.selector, 1e18, 2e18));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 365 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 2e18,
                exactAmountIn: false
            })
        );
    }
}
