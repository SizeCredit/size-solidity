// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {IMarketBorrowRateFeed} from "@src/oracle/IMarketBorrowRateFeed.sol";

struct YieldCurve {
    uint256[] maturities;
    int256[] rates;
    int256[] marketRateMultipliers;
}

/// @title YieldCurveLibrary
/// @notice A library for working with yield curves
///         The yield curve is defined as following:
///         R[t] = rates[t] + marketRateMultipliers[t] * marketRate,
///         for all t in `maturities`, with `marketRate` defined by an external oracle
/// @dev The final rate is an unsigned integer, as it is a percentage
library YieldCurveLibrary {
    // @audit Check if we should have a protocol-defined minimum maturity
    function validateYieldCurve(YieldCurve memory self) internal pure {
        if (self.maturities.length == 0 || self.rates.length == 0 || self.marketRateMultipliers.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (self.maturities.length != self.rates.length || self.maturities.length != self.marketRateMultipliers.length)
        {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }

        // validate curveRelativeTime.rates
        // N/A

        // validate curveRelativeTime.maturities
        uint256 lastMaturity = type(uint256).max;
        for (uint256 i = self.maturities.length; i > 0; i--) {
            if (self.maturities[i - 1] > lastMaturity) {
                revert Errors.MATURITIES_NOT_STRICTLY_INCREASING();
            }
            lastMaturity = self.maturities[i - 1];
        }

        // validate curveRelativeTime.marketRateMultipliers
        // N/A
    }

    /// @notice Get the rate from the yield curve adjusted by the market rate
    /// @dev Reverts if the final result is negative
    ///      Only query the market borro rate feed oracle if the market rate multiplier is not 0
    /// @param rate The constant rate from the yield curve
    /// @param marketBorrowRateFeed The market borrow rate feed
    /// @param marketRateMultiplier The market rate multiplier
    /// @return Returns rate + (marketRate * marketRateMultiplier) / PERCENT
    function getRateAdjustedByMarketRate(
        int256 rate,
        IMarketBorrowRateFeed marketBorrowRateFeed,
        int256 marketRateMultiplier
    ) internal view returns (uint256) {
        // @audit Check if the result should be capped to 0 instead of reverting

        if (marketRateMultiplier == 0) {
            return SafeCast.toUint256(rate);
        } else {
            uint128 marketRate = marketBorrowRateFeed.getMarketBorrowRate();
            return SafeCast.toUint256(
                rate + Math.mulDiv(SafeCast.toInt256(marketRate), marketRateMultiplier, SafeCast.toInt256(PERCENT))
            );
        }
    }

    /// @notice Get the rate from the yield curve by performing a linear interpolation between two time buckets
    /// @dev Reverts if the due date is in the past or out of range
    /// @param curveRelativeTime The yield curve
    /// @param marketBorrowRateFeed The market borrow rate feed
    /// @param dueDate The due date
    /// @return The rate from the yield curve
    function getRate(YieldCurve memory curveRelativeTime, IMarketBorrowRateFeed marketBorrowRateFeed, uint256 dueDate)
        internal
        view
        returns (uint256)
    {
        // @audit Check the correctness of this function
        if (dueDate < block.timestamp) revert Errors.PAST_DUE_DATE(dueDate);
        uint256 interval = dueDate - block.timestamp;
        uint256 length = curveRelativeTime.maturities.length;
        if (interval < curveRelativeTime.maturities[0] || interval > curveRelativeTime.maturities[length - 1]) {
            revert Errors.DUE_DATE_OUT_OF_RANGE(
                interval, curveRelativeTime.maturities[0], curveRelativeTime.maturities[length - 1]
            );
        } else {
            (uint256 low, uint256 high) = Math.binarySearch(curveRelativeTime.maturities, interval);
            uint256 x0 = curveRelativeTime.maturities[low];
            uint256 y0 = getRateAdjustedByMarketRate(
                curveRelativeTime.rates[low], marketBorrowRateFeed, curveRelativeTime.marketRateMultipliers[low]
            );
            uint256 x1 = curveRelativeTime.maturities[high];
            uint256 y1 = getRateAdjustedByMarketRate(
                curveRelativeTime.rates[high], marketBorrowRateFeed, curveRelativeTime.marketRateMultipliers[high]
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
