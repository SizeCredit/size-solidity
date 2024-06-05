// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {BuyCreditLimitParams} from "@src/libraries/actions/BuyCreditLimit.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BuyCreditLimitValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_BuyCreditLimit_validation() public {
        _deposit(alice, usdc, 100e6);
        uint256 maxDueDate = 12 days;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        uint256[] memory tenors = new uint256[](2);
        tenors[0] = 1 days;
        tenors[1] = 2 days;
        int256[] memory rates1 = new int256[](1);
        rates1[0] = 1.01e18;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: rates1})
            })
        );

        int256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: empty})
            })
        );

        int256[] memory aprs = new int256[](2);
        aprs[0] = 1.01e18;
        aprs[1] = 1.02e18;

        tenors[0] = 2 days;
        tenors[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.TENORS_NOT_STRICTLY_INCREASING.selector));
        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        tenors[0] = 6 minutes;
        tenors[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 6 minutes, 1 hours, 5 * 365 days));
        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        tenors[0] = 1 days;
        tenors[1] = 2 days;

        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_MAX_DUE_DATE.selector, 2));
        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: 2,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_MAX_DUE_DATE.selector));
        size.buyCreditLimit(
            BuyCreditLimitParams({
                maxDueDate: 0,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );
    }
}
