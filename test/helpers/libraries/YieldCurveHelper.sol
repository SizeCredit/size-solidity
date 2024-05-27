// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

library YieldCurveHelper {
    // -----------  CURVES -------------

    // Normal Yield Curve: This is the most common shape, where
    // longer-tenor bonds have higher yields than shorter-tenor bonds.
    // It indicates expectations of steady economic growth and
    // gradual interest rate increases.
    function normalCurve() public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](5);
        int256[] memory aprs = new int256[](5);
        uint256[] memory marketRateMultipliers = new uint256[](5);

        aprs[0] = 0.01e18;
        aprs[1] = 0.02e18;
        aprs[2] = 0.03e18;
        aprs[3] = 0.04e18;
        aprs[4] = 0.05e18;

        maturities[0] = 30 days;
        maturities[1] = 60 days;
        maturities[2] = 90 days;
        maturities[3] = 120 days;
        maturities[4] = 150 days;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    // Flat Yield Curve: In a flat yield curve, yields across different
    // maturities are similar. It suggests expectations of little change in
    // interest aprs and reflects economic stability and uncertainty.
    function flatCurve() public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](5);
        int256[] memory aprs = new int256[](5);
        uint256[] memory marketRateMultipliers = new uint256[](5);

        aprs[0] = 0.04e18;
        aprs[1] = 0.04e18;
        aprs[2] = 0.04e18;
        aprs[3] = 0.04e18;
        aprs[4] = 0.04e18;

        maturities[0] = 30 days;
        maturities[1] = 60 days;
        maturities[2] = 90 days;
        maturities[3] = 120 days;
        maturities[4] = 150 days;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    // Inverted Yield Curve: An inverted yield curve occurs when
    // shorter-tenor bonds have higher yields than longer-tenor bonds.
    // It is considered a predictor of an economic recession, as
    // it signals expectations of future interest rate declines.
    function invertedCurve() public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](5);
        int256[] memory aprs = new int256[](5);
        uint256[] memory marketRateMultipliers = new uint256[](5);

        aprs[0] = 0.05e18;
        aprs[1] = 0.04e18;
        aprs[2] = 0.03e18;
        aprs[3] = 0.02e18;
        aprs[4] = 0.04e18;

        maturities[0] = 15 days;
        maturities[1] = 30 days;
        maturities[2] = 60 days;
        maturities[3] = 120 days;
        maturities[4] = 240 days;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    // Humped (or Peaked) Yield Curve: A humped yield curve features higher
    // yields for intermediate-tenor bonds compared to both short-tenor and
    // long-tenor bonds. It may indicate market uncertainty or expectations
    // of changes in monetary policy. This type of curve can be observed during
    // transitional periods or policy shifts by central banks.
    function humpedCurve() public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](5);
        int256[] memory aprs = new int256[](5);
        uint256[] memory marketRateMultipliers = new uint256[](5);

        aprs[0] = 0.01e18;
        aprs[1] = 0.02e18;
        aprs[2] = 0.03e18;
        aprs[3] = 0.02e18;
        aprs[4] = 0.01e18;

        maturities[0] = 1 weeks;
        maturities[1] = 2 weeks;
        maturities[2] = 3 weeks;
        maturities[3] = 4 weeks;
        maturities[4] = 5 weeks;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    // Steep Yield Curve: A steep yield curve indicates a wide spread between
    // short-tenor and long-tenor interest aprs. It suggests expectations of
    // accelerating economic growth and rising inflation. A steep yield curve
    // can benefit banks and financial institutions by allowing them to borrow
    // at lower short-tenor aprs and lend at higher long-tenor aprs.
    function steepCurve() public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](5);
        int256[] memory aprs = new int256[](5);
        uint256[] memory marketRateMultipliers = new uint256[](5);

        aprs[0] = 0.01e18;
        aprs[1] = 0.05e18;
        aprs[2] = 0.06e18;
        aprs[3] = 0.07e18;
        aprs[4] = 0.08e18;

        maturities[0] = 1 hours;
        maturities[1] = 12 hours;
        maturities[2] = 24 days;
        maturities[3] = 48 days;
        maturities[4] = 96 days;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    // Negative Yield Curve: In rare instances, a negative yield curve
    // occurs when longer-tenor bonds have negative yields compared to
    // shorter-tenor bonds. This situation typically arises during
    // periods of extreme market uncertainty, such as
    // financial crises or deflation.
    function negativeCurve() public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](5);
        int256[] memory aprs = new int256[](5);
        uint256[] memory marketRateMultipliers = new uint256[](5);

        aprs[0] = 0.05e18;
        aprs[1] = 0.04e18;
        aprs[2] = 0.03e18;
        aprs[3] = 0.02e18;
        aprs[4] = 0.01e18;

        maturities[0] = 30 days;
        maturities[1] = 60 days;
        maturities[2] = 180 days;
        maturities[3] = 360 days;
        maturities[4] = 720 days;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    // Simple way to create a line between two points, in case you need to
    // test your code with different values that offered by
    // the above the patterns.
    // m1 = 31 days
    // r1 = 0.01e18
    // m2 = 60 days
    // r2 = 0.03e18
    function customCurve(uint256 m1, int256 r1, uint256 m2, int256 r2) public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](2);
        int256[] memory aprs = new int256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);

        aprs[0] = r1;
        aprs[1] = r2;

        maturities[0] = m1;
        maturities[1] = m2;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    function customCurve(uint256 m1, uint256 r1, uint256 m2, uint256 r2) public pure returns (YieldCurve memory) {
        return customCurve(m1, SafeCast.toInt256(r1), m2, SafeCast.toInt256(r2));
    }

    function pointCurve(uint256 m1, int256 r1) public pure returns (YieldCurve memory) {
        uint256[] memory maturities = new uint256[](1);
        int256[] memory aprs = new int256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);

        aprs[0] = r1;

        maturities[0] = m1;

        return YieldCurve({maturities: maturities, aprs: aprs, marketRateMultipliers: marketRateMultipliers});
    }

    function marketCurve() public pure returns (YieldCurve memory curve) {
        curve = normalCurve();

        curve.marketRateMultipliers[0] = 1e18;
        curve.marketRateMultipliers[1] = 1e18;
        curve.marketRateMultipliers[2] = 1e18;
        curve.marketRateMultipliers[3] = 1e18;
        curve.marketRateMultipliers[4] = 1e18;
    }

    function getRandomYieldCurve(uint256 seed) public pure returns (YieldCurve memory) {
        if (seed % 6 == 0) {
            return normalCurve();
        } else if (seed % 6 == 1) {
            return flatCurve();
        } else if (seed % 6 == 2) {
            return invertedCurve();
        } else if (seed % 6 == 3) {
            return humpedCurve();
        } else if (seed % 6 == 4) {
            return steepCurve();
        } else if (seed % 6 == 5) {
            return marketCurve();
        } else {
            return negativeCurve();
        }
    }
}
