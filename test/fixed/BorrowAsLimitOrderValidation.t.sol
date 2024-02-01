// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";

import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/fixed/actions/BorrowAsLimitOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowAsLimitOrderValidationTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrder_validation() public {
        _deposit(alice, weth, 100e18);
        uint256 maxAmount = 100e6;
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates1 = new uint256[](1);
        rates1[0] = 1.01e18;

        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates1})})
        );

        uint256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: empty})})
        );

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e18;
        rates[1] = 1.02e18;

        timeBuckets[0] = 2 days;
        timeBuckets[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.TIME_BUCKETS_NOT_STRICTLY_INCREASING.selector));
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})})
        );
    }
}
