// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {IVariablePoolBorrowRateFeed} from "@src/oracle/IVariablePoolBorrowRateFeed.sol";

struct YieldCurve {
    uint256[] maturities;
    int256[] aprs;
    uint256[] marketRateMultipliers;
}

/// @title YieldCurveLibrary
/// @notice A library for working with yield curves
///         The yield curve is defined as following:
///         R[t] = aprs[t] + marketRateMultipliers[t] * marketRate,
///         for all t in `maturities`, with `marketRate` defined by an external oracle
/// @dev The final rate per maturity is an unsigned integer, as it is a percentage
library YieldCurveLibrary {
    function isNull(YieldCurve memory self) internal pure returns (bool) {
        return self.maturities.length == 0 && self.aprs.length == 0 && self.marketRateMultipliers.length == 0;
    }

    function validateYieldCurve(YieldCurve memory self, uint256 minimumMaturity) internal pure {
        if (self.maturities.length == 0 || self.aprs.length == 0 || self.marketRateMultipliers.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (self.maturities.length != self.aprs.length || self.maturities.length != self.marketRateMultipliers.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }

        // validate aprs
        // N/A

        // validate maturities
        uint256 lastMaturity = type(uint256).max;
        for (uint256 i = self.maturities.length; i != 0; i--) {
            if (self.maturities[i - 1] > lastMaturity) {
                revert Errors.MATURITIES_NOT_STRICTLY_INCREASING();
            }
            lastMaturity = self.maturities[i - 1];
        }
        if (self.maturities[0] < minimumMaturity) {
            revert Errors.MATURITY_BELOW_MINIMUM_MATURITY(self.maturities[0], minimumMaturity);
        }

        // validate marketRateMultipliers
        // N/A
    }

    /// @notice Get the APR from the yield curve adjusted by the variable pool borrow rate
    /// @dev Reverts if the final result is negative
    ///      Only query the market borrow rate feed oracle if the market rate multiplier is not 0
    /// @param apr The annual percentage rate from the yield curve
    /// @param marketRateMultiplier The market rate multiplier
    /// @param variablePoolBorrowRateFeed The market borrow rate feed
    /// @return Returns ratePerMaturity + marketRate * marketRateMultiplier
    function getAdjustedAPR(
        int256 apr,
        uint256 marketRateMultiplier,
        IVariablePoolBorrowRateFeed variablePoolBorrowRateFeed
    ) internal view returns (uint256) {
        // @audit Check if the result should be capped to 0 instead of reverting
        if (marketRateMultiplier == 0) {
            return SafeCast.toUint256(apr);
        } else {
            return SafeCast.toUint256(
                apr
                    + SafeCast.toInt256(
                        Math.mulDivDown(variablePoolBorrowRateFeed.getVariableBorrowRate(), marketRateMultiplier, PERCENT)
                    )
            );
        }
    }

    /// @notice Get the rate from the yield curve by performing a linear interpolation between two time buckets
    /// @dev Reverts if the due date is in the past or out of range
    /// @param curveRelativeTime The yield curve
    /// @param variablePoolBorrowRateFeed The variable pool borrow rate feed
    /// @param maturity The maturity
    /// @return The rate from the yield curve per given maturity
    function getAPR(
        YieldCurve memory curveRelativeTime,
        IVariablePoolBorrowRateFeed variablePoolBorrowRateFeed,
        uint256 maturity
    ) external view returns (uint256) {
        uint256 length = curveRelativeTime.maturities.length;
        if (maturity < curveRelativeTime.maturities[0] || maturity > curveRelativeTime.maturities[length - 1]) {
            revert Errors.MATURITY_OUT_OF_RANGE(
                maturity, curveRelativeTime.maturities[0], curveRelativeTime.maturities[length - 1]
            );
        } else {
            (uint256 low, uint256 high) = Math.binarySearch(curveRelativeTime.maturities, maturity);
            uint256 x0 = curveRelativeTime.maturities[low];
            uint256 y0 = getAdjustedAPR(
                curveRelativeTime.aprs[low], curveRelativeTime.marketRateMultipliers[low], variablePoolBorrowRateFeed
            );
            uint256 x1 = curveRelativeTime.maturities[high];
            uint256 y1 = getAdjustedAPR(
                curveRelativeTime.aprs[high], curveRelativeTime.marketRateMultipliers[high], variablePoolBorrowRateFeed
            );

            if (x1 != x0) {
                if (y1 >= y0) {
                    return y0 + Math.mulDivDown(y1 - y0, maturity - x0, x1 - x0);
                } else {
                    return y0 - Math.mulDivDown(y0 - y1, maturity - x0, x1 - x0);
                }
            } else {
                return y0;
            }
        }
    }
}
