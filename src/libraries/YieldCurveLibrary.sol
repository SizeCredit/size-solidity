// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

struct YieldCurve {
    uint256[] timeBuckets;
    uint256[] rates;
}

library YieldCurveLibrary {
    function getFlatRate(uint256 timeBucketsLength, uint256 rate) public pure returns (YieldCurve memory curve) {
        curve.rates = new uint256[](timeBucketsLength);
        curve.timeBuckets = new uint256[](timeBucketsLength);

        for (uint256 i = 0; i < timeBucketsLength; ++i) {
            curve.rates[i] = rate;
            curve.timeBuckets[i] = i;
        }
    }
}
