// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LendAsMarketOrderValidationTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;

    function test_LendAsMarketOrder_validation() public {
        _setPrice(1e18);
        _deposit(alice, weth, 2 * 150e18);
        _deposit(bob, usdc, 10e6);
        _borrowAsLimitOrder(alice, 0, 12);

        uint256 dueDate = block.timestamp;

        vm.startPrank(bob);

        vm.expectRevert();
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: address(0), dueDate: dueDate, amount: 100e6, exactAmountIn: false})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 10e6, 100e6));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: alice, dueDate: dueDate, amount: 100e6, exactAmountIn: false})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, block.timestamp - 1));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: alice, dueDate: block.timestamp - 1, amount: 100e6, exactAmountIn: false})
        );
    }
}
