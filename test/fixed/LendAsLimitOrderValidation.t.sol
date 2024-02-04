// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LendAsLimitOrderValidationTest is BaseTest {
    using OfferLibrary for FixedLoanOffer;

    function test_LendAsLimitOrder_validation() public {
        _deposit(alice, address(usdc), 100e6);
        uint256 maxDueDate = 12;
        int256[] memory marketRateMultipliers = new int256[](2);
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates1 = new uint256[](1);
        rates1[0] = 1.01e18;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    timeBuckets: timeBuckets,
                    marketRateMultipliers: marketRateMultipliers,
                    rates: rates1
                })
            })
        );

        uint256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    timeBuckets: timeBuckets,
                    marketRateMultipliers: marketRateMultipliers,
                    rates: empty
                })
            })
        );

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e18;
        rates[1] = 1.02e18;

        timeBuckets[0] = 2 days;
        timeBuckets[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.TIME_BUCKETS_NOT_STRICTLY_INCREASING.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    timeBuckets: timeBuckets,
                    marketRateMultipliers: marketRateMultipliers,
                    rates: rates
                })
            })
        );

        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;

        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_MAX_DUE_DATE.selector, 2));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: 2,
                curveRelativeTime: YieldCurve({
                    timeBuckets: timeBuckets,
                    marketRateMultipliers: marketRateMultipliers,
                    rates: rates
                })
            })
        );
    }
}
