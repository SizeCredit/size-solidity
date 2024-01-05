// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Errors} from "@src/libraries/Errors.sol";

struct YieldCurve {
    uint256[] timeBuckets;
    uint256[] rates;
}

library YieldCurveLibrary {
    function validateYieldCurve(YieldCurve memory self) internal pure {
        if (self.timeBuckets.length == 0 || self.rates.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (self.timeBuckets.length != self.rates.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
        // validate curveRelativeTime.timeBuckets
        uint256 lastTimeBucket = type(uint256).max;
        for (uint256 i = self.timeBuckets.length; i > 0; i--) {
            if (self.timeBuckets[i - 1] >= lastTimeBucket) {
                revert Errors.TIME_BUCKETS_NOT_STRICTLY_INCREASING();
            }
            lastTimeBucket = self.timeBuckets[i - 1];
        }
    }
}
