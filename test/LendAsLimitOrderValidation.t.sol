// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest, Vars} from "./BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LendAsLimitOrderValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsLimitOrderValidation() public {
        _deposit(alice, address(usdc), 100e6);
        uint256 maxAmount = 100e18;
        uint256 maxDueDate = 12;
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates1 = new uint256[](1);
        rates1[0] = 1.01e18;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: maxAmount,
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates1})
            })
        );

        uint256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: maxAmount,
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: empty})
            })
        );

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e18;
        rates[1] = 1.02e18;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: 0,
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 100e18, 100e18 + 1));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: maxAmount + 1,
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_MAX_DUE_DATE.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: maxAmount,
                maxDueDate: 0,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );

        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_MAX_DUE_DATE.selector, 2));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxAmount: maxAmount,
                maxDueDate: 2,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );
    }
}
