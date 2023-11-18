// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

struct YieldCurve {
    uint256[] timeBuckets;
    uint256[] rates;
}

library YieldCurveLibrary {
    function getFlatRate(uint256 rate, uint256 timeBucketsLength) public pure returns (YieldCurve memory curve) {
        curve.rates = new uint256[](timeBucketsLength);
        curve.timeBuckets = new uint256[](timeBucketsLength);

        for (uint256 i = 0; i < timeBucketsLength; ++i) {
            curve.rates[i] = rate;
            curve.timeBuckets[i] = i;
        }
    }
}
