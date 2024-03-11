// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/Math.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";

import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";
import {MarketBorrowRateFeedMock} from "@test/mocks/MarketBorrowRateFeedMock.sol";
import {Test} from "forge-std/Test.sol";

contract YieldCurveTest is Test, AssertsHelper {
    MarketBorrowRateFeedMock marketBorrowRateFeed;
    uint256 public constant TOLERANCE_WAD = 10_000;

    function setUp() public {
        marketBorrowRateFeed = new MarketBorrowRateFeedMock(address(this));
        marketBorrowRateFeed.setMarketBorrowRate(0);
    }

    function test_YieldCurve_getRate_below_timestamp() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, 0));
        YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, 0);
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
        YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
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
        YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
    }

    function test_YieldCurve_getRate_first_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[0];
        uint256 rate =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
        assertEqApprox(
            rate, SafeCast.toUint256(Math.linearAPRToRatePerMaturity(curve.aprs[0], interval)), TOLERANCE_WAD
        );
    }

    function test_YieldCurve_getRate_last_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[curve.maturities.length - 1];
        uint256 rate =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
        assertEqApprox(
            rate,
            SafeCast.toUint256(Math.linearAPRToRatePerMaturity(curve.aprs[curve.aprs.length - 1], interval)),
            TOLERANCE_WAD
        );
    }

    function test_YieldCurve_getRate_middle_point() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[2];
        uint256 rate =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
        assertEqApprox(
            rate, SafeCast.toUint256(Math.linearAPRToRatePerMaturity(curve.aprs[2], interval)), TOLERANCE_WAD
        );
    }

    function test_YieldCurve_getRate_point_2_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[1];
        uint256 rate =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
        assertEqApprox(
            rate, SafeCast.toUint256(Math.linearAPRToRatePerMaturity(curve.aprs[1], interval)), TOLERANCE_WAD
        );
    }

    function test_YieldCurve_getRate_point_4_out_of_5() public {
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        uint256 interval = curve.maturities[3];
        uint256 rate =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
        assertEqApprox(
            rate, SafeCast.toUint256(Math.linearAPRToRatePerMaturity(curve.aprs[3], interval)), TOLERANCE_WAD
        );
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
        uint256 rate0 =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + maturityA);

        q0 = bound(q0, p1, curve.maturities.length - 1);
        q1 = bound(q1, q0, curve.maturities.length - 1);
        maturityB = bound(maturityB, curve.maturities[q0], curve.maturities[q1]);
        uint256 rate1 =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + maturityB);
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
        uint256 rate0 =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + maturityA);

        q0 = bound(q0, p1, curve.maturities.length - 1);
        q1 = bound(q1, q0, curve.maturities.length - 1);
        maturityB = bound(maturityB, curve.maturities[q0], curve.maturities[q1]);
        uint256 rate1 =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + maturityB);
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
        uint256 r =
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + interval);
        uint256 apy = SafeCast.toUint256(Math.ratePerMaturityToLinearAPR(SafeCast.toInt256(r), interval));
        assertGe(apy + TOLERANCE_WAD, min);
        assertLe(apy, max + TOLERANCE_WAD);
    }

    function test_YieldCurve_getRate_with_non_null_marketBorrowRate() public {
        YieldCurve memory curve = YieldCurveHelper.marketCurve();
        marketBorrowRateFeed.setMarketBorrowRate(0.31415e18);

        assertEq(
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + 60 days),
            SafeCast.toUint256(Math.linearAPRToRatePerMaturity(0.02e18, 60 days))
                + Math.compoundAPRToRatePerMaturity(0.31415e18, 60 days)
        );
    }

    function test_YieldCurve_getRate_with_negative_rate() public {
        marketBorrowRateFeed.setMarketBorrowRate(0.07e18);
        YieldCurve memory curve = YieldCurveHelper.customCurve(20 days, -0.001e18, 40 days, -0.002e18);
        curve.marketRateMultipliers[0] = 1e18;
        curve.marketRateMultipliers[1] = 1e18;

        assertEqApprox(
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + 30 days),
            Math.compoundAPRToRatePerMaturity(0.07e18, 30 days)
                - SafeCast.toUint256(
                    Math.linearAPRToRatePerMaturity(0.001e18, 20 days) + Math.linearAPRToRatePerMaturity(0.002e18, 40 days)
                ) / 2,
            1e13
        );
    }

    function test_YieldCurve_getRate_with_negative_rate_double_multiplier() public {
        marketBorrowRateFeed.setMarketBorrowRate(0.07e18);
        YieldCurve memory curve = YieldCurveHelper.customCurve(20 days, -0.001e18, 40 days, -0.002e18);
        curve.marketRateMultipliers[0] = 2e18;
        curve.marketRateMultipliers[1] = 2e18;

        assertEqApprox(
            YieldCurveLibrary.getRatePerMaturityByDueDate(curve, marketBorrowRateFeed, block.timestamp + 30 days),
            2 * Math.compoundAPRToRatePerMaturity(0.07e18, 30 days)
                - SafeCast.toUint256(
                    Math.linearAPRToRatePerMaturity(0.001e18, 20 days) + Math.linearAPRToRatePerMaturity(0.002e18, 40 days)
                ) / 2,
            1e13
        );
    }

    function test_YieldCurve_getRate_null_multiplier_does_not_fetch_oracle() public {
        YieldCurve memory curve = YieldCurveHelper.customCurve(30 days, 0.01e18, 60 days, 0.02e18);
        assertEq(
            YieldCurveLibrary.getRatePerMaturityByDueDate(
                curve, IMarketBorrowRateFeed(address(0)), block.timestamp + 45 days
            ),
            SafeCast.toUint256(
                Math.linearAPRToRatePerMaturity(0.01e18, 30 days) + Math.linearAPRToRatePerMaturity(0.02e18, 60 days)
            ) / 2
        );
    }
}
