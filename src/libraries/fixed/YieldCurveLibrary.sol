// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

struct YieldCurve {
    uint256[] timeBuckets;
    int256[] rates;
    uint256[] marketRateMultipliers;
}

/// @title YieldCurveLibrary
/// @notice A library for working with yield curves
library YieldCurveLibrary {
    function isNull(YieldCurve memory self) internal pure returns (bool) {
        return self.timeBuckets.length == 0 && self.rates.length == 0 && self.marketRateMultipliers.length == 0;
    }

    // @audit Check if we should have a protocol-defined minimum maturity
    function validateYieldCurve(YieldCurve memory self, uint256 minimumMaturity) internal pure {
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
        if (self.timeBuckets[0] < minimumMaturity) {
            revert Errors.MATURITY_BELOW_MINIMUM_MATURITY(self.timeBuckets[0], minimumMaturity);
        }

        // validate curveRelativeTime.marketRateMultipliers
        // N/A
    }

    /// @notice Get the rate from the yield curve adjusted by the market rate
    /// @dev Reverts if the final result is negative
    /// @param rate The rate from the yield curve
    /// @param marketRate The market rate
    /// @param marketRateMultiplier The market rate multiplier
    /// @return Returns rate + (marketRate * marketRateMultiplier) / PERCENT
    function getRateAdjustedByMarketRate(int256 rate, uint256 marketRate, uint256 marketRateMultiplier)
        internal
        pure
        returns (uint256)
    {
        // @audit Check if the result should be capped to 0 instead of reverting
        return SafeCast.toUint256(rate + SafeCast.toInt256(Math.mulDivDown(marketRate, marketRateMultiplier, PERCENT)));
    }

    /// @notice Get the rate from the yield curve by performing a linear interpolation between two time buckets
    /// @dev Reverts if the due date is in the past or out of range
    /// @param curveRelativeTime The yield curve
    /// @param marketRate The market rate
    /// @param dueDate The due date
    /// @return The rate from the yield curve
    function getRate(YieldCurve memory curveRelativeTime, uint256 marketRate, uint256 dueDate)
        internal
        view
        returns (uint256)
    {
        // @audit Check the correctness of this function
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
