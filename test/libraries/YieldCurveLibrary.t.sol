// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/Math.sol";
import {VariablePoolBorrowRateParams, YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {Test} from "forge-std/Test.sol";

contract YieldCurveTest is Test, AssertsHelper {
    function validate(YieldCurve memory curve, uint256 minTenor, uint256 maxTenor) external pure {
        YieldCurveLibrary.validateYieldCurve(curve, minTenor, maxTenor);
    }

    function test_YieldCurve_validateYieldCurve() public {
        uint256[] memory tenors = new uint256[](0);
        int256[] memory aprs = new int256[](0);
        uint256[] memory marketRateMultipliers = new uint256[](0);
        uint256 minTenor = 90 days;
        uint256 maxTenor = 5 * 365 days;

        YieldCurve memory curve = YieldCurve({tenors: tenors, aprs: aprs, marketRateMultipliers: marketRateMultipliers});

        try this.validate(curve, minTenor, maxTenor) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.NULL_ARRAY.selector);
        }

        curve.aprs = new int256[](2);
        curve.marketRateMultipliers = new uint256[](2);
        curve.tenors = new uint256[](1);
        try this.validate(curve, minTenor, maxTenor) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.ARRAY_LENGTHS_MISMATCH.selector);
        }

        curve.aprs = new int256[](2);
        curve.marketRateMultipliers = new uint256[](2);
        curve.tenors = new uint256[](2);

        curve.tenors[0] = 30 days;
        curve.tenors[1] = 20 days;

        curve.aprs[0] = 0.1e18;
        curve.aprs[1] = 0.2e18;

        curve.marketRateMultipliers[0] = 1e18;
        curve.marketRateMultipliers[1] = 2e18;

        try this.validate(curve, minTenor, maxTenor) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.TENORS_NOT_STRICTLY_INCREASING.selector);
        }

        curve.tenors[1] = 30 days;
        try this.validate(curve, minTenor, maxTenor) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.TENORS_NOT_STRICTLY_INCREASING.selector);
        }

        curve.tenors[1] = 40 days;
        try this.validate(curve, minTenor, maxTenor) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.TENOR_OUT_OF_RANGE.selector);
        }

        curve.tenors[0] = 150 days;
        curve.tenors[1] = 180 days;
        YieldCurveLibrary.validateYieldCurve(curve, minTenor, maxTenor);
    }

    function test_YieldCurve_getRate_zero_tenor() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TENOR_OUT_OF_RANGE.selector, 0, curve.tenors[0], curve.tenors[curve.tenors.length - 1]
            )
        );
        YieldCurveLibrary.getAPR(curve, params, 0);
    }

    function test_YieldCurve_getRate_below_bounds() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[0] - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TENOR_OUT_OF_RANGE.selector, interval, curve.tenors[0], curve.tenors[curve.tenors.length - 1]
            )
        );
        YieldCurveLibrary.getAPR(curve, params, interval);
    }

    function test_YieldCurve_getRate_after_bounds() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[curve.tenors.length - 1] + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.TENOR_OUT_OF_RANGE.selector, interval, curve.tenors[0], curve.tenors[curve.tenors.length - 1]
            )
        );
        YieldCurveLibrary.getAPR(curve, params, interval);
    }

    function test_YieldCurve_getRate_first_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[0];
        uint256 apr = YieldCurveLibrary.getAPR(curve, params, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[0]));
    }

    function test_YieldCurve_getRate_last_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[curve.tenors.length - 1];
        uint256 apr = YieldCurveLibrary.getAPR(curve, params, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[curve.aprs.length - 1]));
    }

    function test_YieldCurve_getRate_middle_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[2];
        uint256 apr = YieldCurveLibrary.getAPR(curve, params, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[2]));
    }

    function test_YieldCurve_getRate_point_2_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[1];
        uint256 apr = YieldCurveLibrary.getAPR(curve, params, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[1]));
    }

    function test_YieldCurve_getRate_point_4_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        VariablePoolBorrowRateParams memory params;
        uint256 interval = curve.tenors[3];
        uint256 apr = YieldCurveLibrary.getAPR(curve, params, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[3]));
    }

    function testFuzz_YieldCurve_getRate_point_interpolated_slope_eq_0(
        uint256 p0,
        uint256 p1,
        uint256 tenorA,
        uint256 q0,
        uint256 q1,
        uint256 tenorB
    ) public {
        VariablePoolBorrowRateParams memory params;
        YieldCurve memory curve = YieldCurveHelper.flatCurve();
        p0 = bound(p0, 0, curve.tenors.length - 1);
        p1 = bound(p1, p0, curve.tenors.length - 1);
        tenorA = bound(tenorA, curve.tenors[p0], curve.tenors[p1]);
        uint256 rate0 = YieldCurveLibrary.getAPR(curve, params, tenorA);

        q0 = bound(q0, p1, curve.tenors.length - 1);
        q1 = bound(q1, q0, curve.tenors.length - 1);
        tenorB = bound(tenorB, curve.tenors[q0], curve.tenors[q1]);
        uint256 rate1 = YieldCurveLibrary.getAPR(curve, params, tenorB);
        assertLe(rate0, rate1);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_gt_0(
        uint256 p0,
        uint256 p1,
        uint256 tenorA,
        uint256 q0,
        uint256 q1,
        uint256 tenorB
    ) public {
        VariablePoolBorrowRateParams memory params;
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        p0 = bound(p0, 0, curve.tenors.length - 1);
        p1 = bound(p1, p0, curve.tenors.length - 1);
        tenorA = bound(tenorA, curve.tenors[p0], curve.tenors[p1]);
        uint256 rate0 = YieldCurveLibrary.getAPR(curve, params, tenorA);

        q0 = bound(q0, p1, curve.tenors.length - 1);
        q1 = bound(q1, q0, curve.tenors.length - 1);
        tenorB = bound(tenorB, curve.tenors[q0], curve.tenors[q1]);
        uint256 rate1 = YieldCurveLibrary.getAPR(curve, params, tenorB);
        assertLe(rate0, rate1);
    }

    function testFuzz_YieldCurve_getRate_full_random_does_not_revert(
        uint256 seed,
        uint256 p0,
        uint256 p1,
        uint256 interval
    ) public {
        VariablePoolBorrowRateParams memory params = VariablePoolBorrowRateParams({
            variablePoolBorrowRate: 0.31415e18,
            variablePoolBorrowRateUpdatedAt: uint64(block.timestamp),
            variablePoolBorrowRateStaleRateInterval: 1
        });
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        p0 = bound(p0, 0, curve.tenors.length - 1);
        p1 = bound(p1, p0, curve.tenors.length - 1);
        interval = bound(interval, curve.tenors[p0], curve.tenors[p1]);
        uint256 min = type(uint256).max;
        uint256 max = 0;
        for (uint256 i = 0; i < curve.aprs.length; i++) {
            uint256 rate = SafeCast.toUint256(curve.aprs[i]);
            if (rate < min) {
                min = rate;
            }
            if (rate > max) {
                max = rate;
            }
        }
        uint256 apr = YieldCurveLibrary.getAPR(curve, params, interval);
        if (curve.marketRateMultipliers[p0] == 0 && curve.marketRateMultipliers[p1] == 0) {
            assertGe(apr, min);
            assertLe(apr, max);
        }
    }

    function test_YieldCurve_getRate_with_non_null_borrowRate() public {
        YieldCurve memory curve = YieldCurveHelper.marketCurve();
        VariablePoolBorrowRateParams memory params = VariablePoolBorrowRateParams({
            variablePoolBorrowRate: 0.31415e18,
            variablePoolBorrowRateUpdatedAt: uint64(block.timestamp),
            variablePoolBorrowRateStaleRateInterval: 1
        });

        assertEq(YieldCurveLibrary.getAPR(curve, params, 60 days), 0.02e18 + 0.31415e18);
    }

    function test_YieldCurve_getRate_with_negative_rate() public {
        VariablePoolBorrowRateParams memory params = VariablePoolBorrowRateParams({
            variablePoolBorrowRate: 0.07e18,
            variablePoolBorrowRateUpdatedAt: uint64(block.timestamp),
            variablePoolBorrowRateStaleRateInterval: 1
        });
        YieldCurve memory curve = YieldCurveHelper.customCurve(20 days, -0.001e18, 40 days, -0.002e18);
        curve.marketRateMultipliers[0] = 1e18;
        curve.marketRateMultipliers[1] = 1e18;

        assertEq(YieldCurveLibrary.getAPR(curve, params, 30 days), 0.07e18 - 0.0015e18);
    }

    function test_YieldCurve_getRate_with_negative_rate_double_multiplier() public {
        VariablePoolBorrowRateParams memory params = VariablePoolBorrowRateParams({
            variablePoolBorrowRate: 0.07e18,
            variablePoolBorrowRateUpdatedAt: uint64(block.timestamp),
            variablePoolBorrowRateStaleRateInterval: 1
        });
        YieldCurve memory curve = YieldCurveHelper.customCurve(20 days, -0.001e18, 40 days, -0.002e18);
        curve.marketRateMultipliers[0] = 2e18;
        curve.marketRateMultipliers[1] = 2e18;

        assertEq(YieldCurveLibrary.getAPR(curve, params, 30 days), 2 * 0.07e18 - 0.0015e18);
    }

    function test_YieldCurve_getRate_null_multiplier_does_not_fetch_oracle() public {
        VariablePoolBorrowRateParams memory params;
        YieldCurve memory curve = YieldCurveHelper.customCurve(30 days, uint256(0.01e18), 60 days, uint256(0.02e18));
        assertEq(YieldCurveLibrary.getAPR(curve, params, 45 days), 0.015e18);
    }
}
