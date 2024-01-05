// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";
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

    function getRate(YieldCurve memory curveRelativeTime, uint256 dueDate) public view returns (uint256) {
        if (dueDate < block.timestamp) revert Errors.PAST_DUE_DATE(dueDate);
        uint256 deltaT = dueDate - block.timestamp;
        uint256 length = curveRelativeTime.timeBuckets.length;
        if (deltaT < curveRelativeTime.timeBuckets[0] || deltaT > curveRelativeTime.timeBuckets[length - 1]) {
            revert Errors.DUE_DATE_OUT_OF_RANGE(
                deltaT, curveRelativeTime.timeBuckets[0], curveRelativeTime.timeBuckets[length - 1]
            );
        } else {
            uint256 minIndex = type(uint256).max;
            uint256 maxIndex = type(uint256).max;
            for (uint256 i = 0; i < length; ++i) {
                if (curveRelativeTime.timeBuckets[i] <= deltaT) {
                    minIndex = i;
                }
                if (curveRelativeTime.timeBuckets[i] >= deltaT && maxIndex == type(uint256).max) {
                    maxIndex = i;
                }
            }
            uint256 x0 = curveRelativeTime.timeBuckets[minIndex];
            uint256 y0 = curveRelativeTime.rates[minIndex];
            uint256 x1 = curveRelativeTime.timeBuckets[maxIndex];
            uint256 y1 = curveRelativeTime.rates[maxIndex];
            if (x1 != x0) {
                // @audit Check the rounding direction, as this may lead debt rounding down
                return y0 + Math.mulDivDown(y1 - y0, deltaT - x0, x1 - x0);
            } else {
                return y0;
            }
        }
    }
}
