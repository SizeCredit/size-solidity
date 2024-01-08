// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {Test} from "forge-std/Test.sol";

contract YieldCurveTest is Test {
    function test_YieldCurve_getRate_below_timestamp() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        YieldCurveLibrary.getRate(curve, 0);
    }

    function test_YieldCurve_getRate_below_bounds() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[0] - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_OUT_OF_RANGE.selector,
                interval,
                curve.timeBuckets[0],
                curve.timeBuckets[curve.timeBuckets.length - 1]
            )
        );
        YieldCurveLibrary.getRate(curve, block.timestamp + interval);
    }

    function test_YieldCurve_getRate_after_bounds() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[curve.timeBuckets.length - 1] + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_OUT_OF_RANGE.selector,
                interval,
                curve.timeBuckets[0],
                curve.timeBuckets[curve.timeBuckets.length - 1]
            )
        );
        YieldCurveLibrary.getRate(curve, block.timestamp + interval);
    }

    function test_YieldCurve_getRate_first_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[0];
        uint256 rate = YieldCurveLibrary.getRate(curve, block.timestamp + interval);
        assertEq(rate, curve.rates[0]);
    }

    function test_YieldCurve_getRate_last_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[curve.timeBuckets.length - 1];
        uint256 rate = YieldCurveLibrary.getRate(curve, block.timestamp + interval);
        assertEq(rate, curve.rates[curve.rates.length - 1]);
    }

    function test_YieldCurve_getRate_middle_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[2];
        uint256 rate = YieldCurveLibrary.getRate(curve, block.timestamp + interval);
        assertEq(rate, curve.rates[2]);
    }

    function test_YieldCurve_getRate_point_2_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[1];
        uint256 rate = YieldCurveLibrary.getRate(curve, block.timestamp + interval);
        assertEq(rate, curve.rates[1]);
    }

    function test_YieldCurve_getRate_point_4_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[3];
        uint256 rate = YieldCurveLibrary.getRate(curve, block.timestamp + interval);
        assertEq(rate, curve.rates[3]);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_eq_0(uint256 interval) public {
        YieldCurve memory curve = YieldCurveHelper.flatCurve();
        interval = bound(interval, curve.timeBuckets[0], curve.timeBuckets[curve.timeBuckets.length - 1]);
        uint256 rate = YieldCurveLibrary.getRate(curve, block.timestamp + interval);
        assertEq(rate, curve.rates[0]);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_lt_0(uint256 interval1, uint256 interval0) public {
        YieldCurve memory curve = YieldCurveHelper.invertedCurve();
        interval0 = bound(interval0, curve.timeBuckets[0], curve.timeBuckets[1]);
        uint256 rate0 = YieldCurveLibrary.getRate(curve, block.timestamp + interval0);

        interval1 = bound(interval1, curve.timeBuckets[3], curve.timeBuckets[4]);
        uint256 rate1 = YieldCurveLibrary.getRate(curve, block.timestamp + interval1);
        assertLt(rate1, rate0);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_gt_0(uint256 interval0, uint256 interval1) public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        interval0 = bound(interval0, curve.timeBuckets[0], curve.timeBuckets[1]);
        uint256 rate0 = YieldCurveLibrary.getRate(curve, block.timestamp + interval0);

        interval1 = bound(interval1, curve.timeBuckets[3], curve.timeBuckets[4]);
        uint256 rate1 = YieldCurveLibrary.getRate(curve, block.timestamp + interval1);
        assertGt(rate1, rate0);
    }

    function test_YieldCurve_getRate_full_random_does_not_revert(uint256 seed, uint256 p0, uint256 p1, uint256 interval)
        public
    {
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        p0 = bound(p0, 0, curve.timeBuckets.length - 1);
        p1 = bound(p1, p0, curve.timeBuckets.length - 1);
        interval = bound(interval, curve.timeBuckets[p0], curve.timeBuckets[p1]);
        YieldCurveLibrary.getRate(curve, block.timestamp + interval);
    }
}
