// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Errors} from "@src/libraries/Errors.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {Test} from "forge-std/Test.sol";

contract YieldCurveTest is Test {
    function test_YieldCurve_getRate_below_timestamp() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        YieldCurveLibrary.getRate(curve, 0, 0);
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
        YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
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
        YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
    }

    function test_YieldCurve_getRate_first_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[0];
        uint256 rate = YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
        assertEq(rate, curve.rates[0]);
    }

    function test_YieldCurve_getRate_last_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[curve.timeBuckets.length - 1];
        uint256 rate = YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
        assertEq(rate, curve.rates[curve.rates.length - 1]);
    }

    function test_YieldCurve_getRate_middle_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[2];
        uint256 rate = YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
        assertEq(rate, curve.rates[2]);
    }

    function test_YieldCurve_getRate_point_2_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[1];
        uint256 rate = YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
        assertEq(rate, curve.rates[1]);
    }

    function test_YieldCurve_getRate_point_4_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.timeBuckets[3];
        uint256 rate = YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
        assertEq(rate, curve.rates[3]);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_eq_0(
        uint256 p0,
        uint256 p1,
        uint256 ip,
        uint256 q0,
        uint256 q1,
        uint256 iq
    ) public {
        YieldCurve memory curve = YieldCurveHelper.flatCurve();
        p0 = bound(p0, 0, curve.timeBuckets.length - 1);
        p1 = bound(p1, p0, curve.timeBuckets.length - 1);
        ip = bound(ip, curve.timeBuckets[p0], curve.timeBuckets[p1]);
        uint256 rate0 = YieldCurveLibrary.getRate(curve, 0, block.timestamp + ip);

        q0 = bound(q0, 0, curve.timeBuckets.length - 1);
        q1 = bound(q1, q0, curve.timeBuckets.length - 1);
        iq = bound(ip, curve.timeBuckets[q0], curve.timeBuckets[q1]);
        uint256 rate1 = YieldCurveLibrary.getRate(curve, 0, block.timestamp + iq);
        assertEq(rate1, rate0);
        assertEq(rate0, curve.rates[0]);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_lt_0(
        uint256 p0,
        uint256 p1,
        uint256 ip,
        uint256 q0,
        uint256 q1,
        uint256 iq
    ) public {
        YieldCurve memory curve = YieldCurveHelper.negativeCurve();
        p0 = bound(p0, 0, curve.timeBuckets.length - 1);
        p1 = bound(p1, p0, curve.timeBuckets.length - 1);
        ip = bound(ip, curve.timeBuckets[p0], curve.timeBuckets[p1]);
        uint256 rate0 = YieldCurveLibrary.getRate(curve, 0, block.timestamp + ip);

        q0 = bound(q0, p1, curve.timeBuckets.length - 1);
        q1 = bound(q1, q0, curve.timeBuckets.length - 1);
        iq = bound(ip, curve.timeBuckets[q0], curve.timeBuckets[q1]);
        uint256 rate1 = YieldCurveLibrary.getRate(curve, 0, block.timestamp + iq);
        assertLe(rate1, rate0);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_gt_0(
        uint256 p0,
        uint256 p1,
        uint256 ip,
        uint256 q0,
        uint256 q1,
        uint256 iq
    ) public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        p0 = bound(p0, 0, curve.timeBuckets.length - 1);
        p1 = bound(p1, p0, curve.timeBuckets.length - 1);
        ip = bound(ip, curve.timeBuckets[p0], curve.timeBuckets[p1]);
        uint256 rate0 = YieldCurveLibrary.getRate(curve, 0, block.timestamp + ip);

        q0 = bound(q0, p1, curve.timeBuckets.length - 1);
        q1 = bound(q1, q0, curve.timeBuckets.length - 1);
        iq = bound(ip, curve.timeBuckets[q0], curve.timeBuckets[q1]);
        uint256 rate1 = YieldCurveLibrary.getRate(curve, 0, block.timestamp + iq);
        assertGe(rate1, rate0);
    }

    function testFuzz_YieldCurve_getRate_full_random_does_not_revert(
        uint256 seed,
        uint256 p0,
        uint256 p1,
        uint256 interval
    ) public {
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        p0 = bound(p0, 0, curve.timeBuckets.length - 1);
        p1 = bound(p1, p0, curve.timeBuckets.length - 1);
        interval = bound(interval, curve.timeBuckets[p0], curve.timeBuckets[p1]);
        uint256 min = type(uint256).max;
        uint256 max = 0;
        for (uint256 i = 0; i < curve.rates.length; i++) {
            uint256 rate = curve.rates[i];
            if (rate < min) {
                min = rate;
            }
            if (rate > max) {
                max = rate;
            }
        }
        uint256 r = YieldCurveLibrary.getRate(curve, 0, block.timestamp + interval);
        assertGe(r, min);
        assertLe(r, max);
    }

    function test_YieldCurve_getRate_with_non_null_marketBorrowRate() public {
        YieldCurve memory curve = YieldCurveHelper.marketCurve();

        assertEq(YieldCurveLibrary.getRate(curve, 0.31415e18, block.timestamp + 60 days), 0.31415e18 + 0.02e18);
    }

    function test_YieldCurve_getRate_with_non_null_marketBorrowRate_negative_multiplier() public {
        YieldCurve memory curve = YieldCurveHelper.negativeMarketCurve();

        assertEq(YieldCurveLibrary.getRate(curve, 0.01337e18, block.timestamp + 60 days), 0.04e18 - 0.01337e18);
    }
}
