// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

struct YieldCurve {
    uint256[] timeBuckets;
    uint256[] rates;
    int256[] marketRateMultipliers;
}

library YieldCurveLibrary {
    // @audit Check if we should have a protocol-defined minimum maturity
    function validateYieldCurve(YieldCurve memory self) internal pure {
        if (self.timeBuckets.length == 0 || self.rates.length == 0 || self.marketRateMultipliers.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (
            self.timeBuckets.length != self.rates.length || self.timeBuckets.length != self.marketRateMultipliers.length
        ) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }

        // validate curveRelativeTime.rates
        // N/A

        // validate curveRelativeTime.timeBuckets
        uint256 lastTimeBucket = type(uint256).max;
        for (uint256 i = self.timeBuckets.length; i > 0; i--) {
            if (self.timeBuckets[i - 1] >= lastTimeBucket) {
                revert Errors.TIME_BUCKETS_NOT_STRICTLY_INCREASING();
            }
            lastTimeBucket = self.timeBuckets[i - 1];
        }

        // validate curveRelativeTime.marketRateMultipliers
        // N/A
    }

    function getRateAdjustedByMarketRate(uint256 rate, uint256 marketRate, int256 marketRateMultiplier)
        internal
        pure
        returns (uint256)
    {
        return SafeCast.toUint256(
            SafeCast.toInt256(rate)
                + Math.mulDiv(SafeCast.toInt256(marketRate), marketRateMultiplier, SafeCast.toInt256(PERCENT))
        );
    }

    function getRate(YieldCurve memory curveRelativeTime, uint256 marketRate, uint256 dueDate)
        internal
        view
        returns (uint256)
    {
        if (dueDate < block.timestamp) revert Errors.PAST_DUE_DATE(dueDate);
        uint256 interval = dueDate - block.timestamp;
        uint256 length = curveRelativeTime.timeBuckets.length;
        if (interval < curveRelativeTime.timeBuckets[0] || interval > curveRelativeTime.timeBuckets[length - 1]) {
            revert Errors.DUE_DATE_OUT_OF_RANGE(
                interval, curveRelativeTime.timeBuckets[0], curveRelativeTime.timeBuckets[length - 1]
            );
        } else {
            (uint256 low, uint256 high) = Math.binarySearch(curveRelativeTime.timeBuckets, interval);
            uint256 x0 = curveRelativeTime.timeBuckets[low];
            uint256 y0 = getRateAdjustedByMarketRate(
                curveRelativeTime.rates[low], marketRate, curveRelativeTime.marketRateMultipliers[low]
            );
            uint256 x1 = curveRelativeTime.timeBuckets[high];
            uint256 y1 = getRateAdjustedByMarketRate(
                curveRelativeTime.rates[high], marketRate, curveRelativeTime.marketRateMultipliers[high]
            );

            // @audit Check the rounding direction, as this may lead to debt rounding down
            if (x1 != x0) {
                if (y1 >= y0) {
                    return y0 + Math.mulDivDown(y1 - y0, interval - x0, x1 - x0);
                } else {
                    return y0 - Math.mulDivDown(y0 - y1, interval - x0, x1 - x0);
                }
            } else {
                return y0;
            }
        }
    }
}
