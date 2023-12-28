// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

library YieldCurveHelper {
    // -----------  CURVES -------------

    // Normal Yield Curve: This is the most common shape, where
    // longer-maturity bonds have higher yields than shorter-maturity bonds.
    // It indicates expectations of steady economic growth and
    // gradual interest rate increases.
    function normalCurve() public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](5);
        uint256[] memory rates = new uint256[](5);

        rates[0] = 0.01e18;
        rates[1] = 0.02e18;
        rates[2] = 0.03e18;
        rates[3] = 0.04e18;
        rates[4] = 0.05e18;

        timeBuckets[0] = 30 days;
        timeBuckets[1] = 60 days;
        timeBuckets[2] = 90 days;
        timeBuckets[3] = 120 days;
        timeBuckets[4] = 150 days;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }

    // Flat Yield Curve: In a flat yield curve, yields across different
    // maturities are similar. It suggests expectations of little change in
    // interest rates and reflects economic stability and uncertainty.
    function flatCurve() public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](5);
        uint256[] memory rates = new uint256[](5);

        rates[0] = 0.04e18;
        rates[1] = 0.04e18;
        rates[2] = 0.04e18;
        rates[3] = 0.04e18;
        rates[4] = 0.04e18;

        timeBuckets[0] = 30 days;
        timeBuckets[1] = 60 days;
        timeBuckets[2] = 90 days;
        timeBuckets[3] = 120 days;
        timeBuckets[4] = 150 days;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }

    // Inverted Yield Curve: An inverted yield curve occurs when
    // shorter-maturity bonds have higher yields than longer-maturity bonds.
    // It is considered a predictor of an economic recession, as
    // it signals expectations of future interest rate declines.
    function invertedCurve() public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](5);
        uint256[] memory rates = new uint256[](5);

        rates[0] = 0.05e18;
        rates[1] = 0.04e18;
        rates[2] = 0.03e18;
        rates[3] = 0.02e18;
        rates[4] = 0.04e18;

        timeBuckets[0] = 30 days;
        timeBuckets[1] = 60 days;
        timeBuckets[2] = 90 days;
        timeBuckets[3] = 120 days;
        timeBuckets[4] = 150 days;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }

    // Humped (or Peaked) Yield Curve: A humped yield curve features higher
    // yields for intermediate-maturity bonds compared to both short-maturity and
    // long-maturity bonds. It may indicate market uncertainty or expectations
    // of changes in monetary policy. This type of curve can be observed during
    // transitional periods or policy shifts by central banks.
    function humpedCurve() public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](5);
        uint256[] memory rates = new uint256[](5);

        rates[0] = 0.01e18;
        rates[1] = 0.02e18;
        rates[2] = 0.03e18;
        rates[3] = 0.02e18;
        rates[4] = 0.01e18;

        timeBuckets[0] = 30 days;
        timeBuckets[1] = 60 days;
        timeBuckets[2] = 90 days;
        timeBuckets[3] = 120 days;
        timeBuckets[4] = 150 days;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }

    // Steep Yield Curve: A steep yield curve indicates a wide spread between
    // short-maturity and long-maturity interest rates. It suggests expectations of
    // accelerating economic growth and rising inflation. A steep yield curve
    // can benefit banks and financial institutions by allowing them to borrow
    // at lower short-maturity rates and lend at higher long-maturity rates.
    function steepCurve() public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](5);
        uint256[] memory rates = new uint256[](5);

        rates[0] = 0.01e18;
        rates[1] = 0.02e18;
        rates[2] = 0.03e18;
        rates[3] = 0.02e18;
        rates[4] = 0.01e18;

        timeBuckets[0] = 30 days;
        timeBuckets[1] = 60 days;
        timeBuckets[2] = 90 days;
        timeBuckets[3] = 120 days;
        timeBuckets[4] = 150 days;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }

    // Negative Yield Curve: In rare instances, a negative yield curve
    // occurs when longer-maturity bonds have negative yields compared to
    // shorter-maturity bonds. This situation typically arises during
    // periods of extreme market uncertainty, such as
    // financial crises or deflation.
    function negativeCurve() public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](5);
        uint256[] memory rates = new uint256[](5);

        rates[0] = 0.05e18;
        rates[1] = 0.04e18;
        rates[2] = 0.03e18;
        rates[3] = 0.02e18;
        rates[4] = 0.01e18;

        timeBuckets[0] = 30 days;
        timeBuckets[1] = 60 days;
        timeBuckets[2] = 90 days;
        timeBuckets[3] = 120 days;
        timeBuckets[4] = 150 days;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }

    // Simple way to create a line between two points, in case you need to
    // test your code with different values that offered by
    // the above the patterns.
    // m1 = 31 days
    // r1 = 100 [1% in BPS]
    // m2 = 60 days
    // r2 = 300 [3% in BPS]
    function customCurve(uint128 m1, uint24 r1, uint128 m2, uint24 r2) public pure returns (YieldCurve memory) {
        uint256[] memory timeBuckets = new uint256[](2);
        uint256[] memory rates = new uint256[](2);

        rates[0] = r1;
        rates[1] = r2;

        timeBuckets[0] = m1;
        timeBuckets[1] = m2;

        return YieldCurve({timeBuckets: timeBuckets, rates: rates});
    }
}
