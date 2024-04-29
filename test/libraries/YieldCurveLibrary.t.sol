// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/Math.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";

import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {VariablePoolBorrowRateFeedMock} from "@test/mocks/VariablePoolBorrowRateFeedMock.sol";
import {Test} from "forge-std/Test.sol";

contract YieldCurveTest is Test, AssertsHelper {
    VariablePoolBorrowRateFeedMock variablePoolBorrowRateFeed;

    function setUp() public {
        variablePoolBorrowRateFeed = new VariablePoolBorrowRateFeedMock(address(this));
        variablePoolBorrowRateFeed.setVariableBorrowRate(0);
    }

    function validate(YieldCurve memory curve, uint256 minimumMaturity) external pure {
        YieldCurveLibrary.validateYieldCurve(curve, minimumMaturity);
    }

    function test_YieldCurve_validateYieldCurve() public {
        uint256[] memory maturities = new uint256[](0);
        int256[] memory aprs = new int256[](0);
        uint256[] memory marketRateMultipliers = new uint256[](0);
        uint256 minimumMaturity = 90 days;

        YieldCurve memory curve =
            YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});

        try this.validate(curve, minimumMaturity) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.NULL_ARRAY.selector);
        }

        curve.aprs = new int256[](2);
        curve.marketRateMultipliers = new uint256[](2);
        curve.maturities = new uint256[](1);
        try this.validate(curve, minimumMaturity) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.ARRAY_LENGTHS_MISMATCH.selector);
        }

        curve.aprs = new int256[](2);
        curve.marketRateMultipliers = new uint256[](2);
        curve.maturities = new uint256[](2);

        curve.maturities[0] = 30 days;
        curve.maturities[1] = 20 days;

        curve.aprs[0] = 0.1e18;
        curve.aprs[1] = 0.2e18;

        curve.marketRateMultipliers[0] = 1e18;
        curve.marketRateMultipliers[1] = 2e18;

        try this.validate(curve, minimumMaturity) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.MATURITIES_NOT_STRICTLY_INCREASING.selector);
        }

        curve.maturities[1] = 30 days;
        try this.validate(curve, minimumMaturity) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.MATURITIES_NOT_STRICTLY_INCREASING.selector);
        }

        curve.maturities[1] = 40 days;
        try this.validate(curve, minimumMaturity) {}
        catch (bytes memory err) {
            assertEq(bytes4(err), Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector);
        }

        curve.maturities[0] = 150 days;
        curve.maturities[1] = 180 days;
        YieldCurveLibrary.validateYieldCurve(curve, minimumMaturity);
    }

    function test_YieldCurve_getRate_zero_maturity() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MATURITY_OUT_OF_RANGE.selector,
                0,
                curve.maturities[0],
                curve.maturities[curve.maturities.length - 1]
            )
        );
        YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, 0);
    }

    function test_YieldCurve_getRate_below_bounds() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[0] - 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MATURITY_OUT_OF_RANGE.selector,
                interval,
                curve.maturities[0],
                curve.maturities[curve.maturities.length - 1]
            )
        );
        YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
    }

    function test_YieldCurve_getRate_after_bounds() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[curve.maturities.length - 1] + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.MATURITY_OUT_OF_RANGE.selector,
                interval,
                curve.maturities[0],
                curve.maturities[curve.maturities.length - 1]
            )
        );
        YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
    }

    function test_YieldCurve_getRate_first_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[0];
        uint256 apr = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[0]));
    }

    function test_YieldCurve_getRate_last_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[curve.maturities.length - 1];
        uint256 apr = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[curve.aprs.length - 1]));
    }

    function test_YieldCurve_getRate_middle_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[2];
        uint256 apr = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[2]));
    }

    function test_YieldCurve_getRate_point_2_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[1];
        uint256 apr = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[1]));
    }

    function test_YieldCurve_getRate_point_4_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[3];
        uint256 apr = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
        assertEq(apr, SafeCast.toUint256(curve.aprs[3]));
    }

    function testFuzz_YieldCurve_getRate_point_interpolated_slope_eq_0(
        uint256 p0,
        uint256 p1,
        uint256 maturityA,
        uint256 q0,
        uint256 q1,
        uint256 maturityB
    ) public {
        YieldCurve memory curve = YieldCurveHelper.flatCurve();
        p0 = bound(p0, 0, curve.maturities.length - 1);
        p1 = bound(p1, p0, curve.maturities.length - 1);
        maturityA = bound(maturityA, curve.maturities[p0], curve.maturities[p1]);
        uint256 rate0 = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, maturityA);

        q0 = bound(q0, p1, curve.maturities.length - 1);
        q1 = bound(q1, q0, curve.maturities.length - 1);
        maturityB = bound(maturityB, curve.maturities[q0], curve.maturities[q1]);
        uint256 rate1 = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, maturityB);
        assertLe(rate0, rate1);
    }

    function test_YieldCurve_getRate_point_interpolated_slope_gt_0(
        uint256 p0,
        uint256 p1,
        uint256 maturityA,
        uint256 q0,
        uint256 q1,
        uint256 maturityB
    ) public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        p0 = bound(p0, 0, curve.maturities.length - 1);
        p1 = bound(p1, p0, curve.maturities.length - 1);
        maturityA = bound(maturityA, curve.maturities[p0], curve.maturities[p1]);
        uint256 rate0 = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, maturityA);

        q0 = bound(q0, p1, curve.maturities.length - 1);
        q1 = bound(q1, q0, curve.maturities.length - 1);
        maturityB = bound(maturityB, curve.maturities[q0], curve.maturities[q1]);
        uint256 rate1 = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, maturityB);
        assertLe(rate0, rate1);
    }

    function testFuzz_YieldCurve_getRate_full_random_does_not_revert(
        uint256 seed,
        uint256 p0,
        uint256 p1,
        uint256 interval
    ) public {
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        p0 = bound(p0, 0, curve.maturities.length - 1);
        p1 = bound(p1, p0, curve.maturities.length - 1);
        interval = bound(interval, curve.maturities[p0], curve.maturities[p1]);
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
        uint256 apr = YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, interval);
        assertGe(apr, min);
        assertLe(apr, max);
    }

    function test_YieldCurve_getRate_with_non_null_borrowRate() public {
        YieldCurve memory curve = YieldCurveHelper.marketCurve();
        variablePoolBorrowRateFeed.setVariableBorrowRate(0.31415e18);

        assertEq(YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, 60 days), 0.02e18 + 0.31415e18);
    }

    function test_YieldCurve_getRate_with_negative_rate() public {
        variablePoolBorrowRateFeed.setVariableBorrowRate(0.07e18);
        YieldCurve memory curve = YieldCurveHelper.customCurve(20 days, -0.001e18, 40 days, -0.002e18);
        curve.marketRateMultipliers[0] = 1e18;
        curve.marketRateMultipliers[1] = 1e18;

        assertEq(YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, 30 days), 0.07e18 - 0.0015e18);
    }

    function test_YieldCurve_getRate_with_negative_rate_double_multiplier() public {
        variablePoolBorrowRateFeed.setVariableBorrowRate(0.07e18);
        YieldCurve memory curve = YieldCurveHelper.customCurve(20 days, -0.001e18, 40 days, -0.002e18);
        curve.marketRateMultipliers[0] = 2e18;
        curve.marketRateMultipliers[1] = 2e18;

        assertEq(YieldCurveLibrary.getAPR(curve, variablePoolBorrowRateFeed, 30 days), 2 * 0.07e18 - 0.0015e18);
    }

    function test_YieldCurve_getRate_null_multiplier_does_not_fetch_oracle() public {
        YieldCurve memory curve = YieldCurveHelper.customCurve(30 days, uint256(0.01e18), 60 days, uint256(0.02e18));
        assertEq(YieldCurveLibrary.getAPR(curve, IVariablePoolBorrowRateFeed(address(0)), 45 days), 0.015e18);
    }
}
