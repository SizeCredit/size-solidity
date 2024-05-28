// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

struct YieldCurve {
    uint256[] tenors;
    int256[] aprs;
    uint256[] marketRateMultipliers;
}

struct VariablePoolBorrowRateParams {
    uint128 variablePoolBorrowRate;
    uint64 variablePoolBorrowRateUpdatedAt;
    uint64 variablePoolBorrowRateStaleRateInterval;
}

/// @title YieldCurveLibrary
/// @notice A library for working with yield curves
///         The yield curve is defined as following:
///         R[t] = aprs[t] + marketRateMultipliers[t] * marketRate,
///         for all t in `tenors`, with `marketRate` defined by an external oracle
/// @dev The final rate per tenor is an unsigned integer, as it is a percentage
library YieldCurveLibrary {
    function isNull(YieldCurve memory self) internal pure returns (bool) {
        return self.tenors.length == 0 && self.aprs.length == 0 && self.marketRateMultipliers.length == 0;
    }

    function validateYieldCurve(YieldCurve memory self, uint256 minimumTenor, uint256 maximumTenor) internal pure {
        if (self.tenors.length == 0 || self.aprs.length == 0 || self.marketRateMultipliers.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (self.tenors.length != self.aprs.length || self.tenors.length != self.marketRateMultipliers.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }

        // validate aprs
        // N/A

        // validate tenors
        uint256 lastTenor = type(uint256).max;
        for (uint256 i = self.tenors.length; i != 0; i--) {
            if (self.tenors[i - 1] >= lastTenor) {
                revert Errors.TENORS_NOT_STRICTLY_INCREASING();
            }
            lastTenor = self.tenors[i - 1];
        }
        if (self.tenors[0] < minimumTenor) {
            revert Errors.TENOR_BELOW_MINIMUM_TENOR(self.tenors[0], minimumTenor);
        }
        if (self.tenors[self.tenors.length - 1] > maximumTenor) {
            revert Errors.TENOR_GREATER_THAN_MAXIMUM_TENOR(self.tenors[self.tenors.length - 1], maximumTenor);
        }

        // validate marketRateMultipliers
        // N/A
    }

    /// @notice Get the APR from the yield curve adjusted by the variable pool borrow rate
    /// @dev Reverts if the final result is negative
    ///      Only query the market borrow rate feed oracle if the market rate multiplier is not 0
    /// @param apr The annual percentage rate from the yield curve
    /// @param marketRateMultiplier The market rate multiplier
    /// @param params The variable pool borrow rate feed params
    /// @return Returns ratePerTenor + marketRate * marketRateMultiplier
    function getAdjustedAPR(int256 apr, uint256 marketRateMultiplier, VariablePoolBorrowRateParams memory params)
        internal
        view
        returns (uint256)
    {
        if (marketRateMultiplier == 0) {
            return SafeCast.toUint256(apr);
        } else if (
            block.timestamp - params.variablePoolBorrowRateUpdatedAt > params.variablePoolBorrowRateStaleRateInterval
        ) {
            revert Errors.STALE_RATE(params.variablePoolBorrowRateUpdatedAt);
        } else {
            return SafeCast.toUint256(
                apr + SafeCast.toInt256(Math.mulDivDown(params.variablePoolBorrowRate, marketRateMultiplier, PERCENT))
            );
        }
    }

    /// @notice Get the rate from the yield curve by performing a linear interpolation between two time buckets
    /// @dev Reverts if the due date is in the past or out of range
    /// @param curveRelativeTime The yield curve
    /// @param params The variable pool borrow rate feed params
    /// @param tenor The tenor
    /// @return The rate from the yield curve per given tenor
    function getAPR(YieldCurve memory curveRelativeTime, VariablePoolBorrowRateParams memory params, uint256 tenor)
        external
        view
        returns (uint256)
    {
        uint256 length = curveRelativeTime.tenors.length;
        if (tenor < curveRelativeTime.tenors[0] || tenor > curveRelativeTime.tenors[length - 1]) {
            revert Errors.TENOR_OUT_OF_RANGE(tenor, curveRelativeTime.tenors[0], curveRelativeTime.tenors[length - 1]);
        } else {
            (uint256 low, uint256 high) = Math.binarySearch(curveRelativeTime.tenors, tenor);
            uint256 y0 =
                getAdjustedAPR(curveRelativeTime.aprs[low], curveRelativeTime.marketRateMultipliers[low], params);

            if (low != high) {
                uint256 x0 = curveRelativeTime.tenors[low];
                uint256 x1 = curveRelativeTime.tenors[high];
                uint256 y1 =
                    getAdjustedAPR(curveRelativeTime.aprs[high], curveRelativeTime.marketRateMultipliers[high], params);

                if (y1 >= y0) {
                    return y0 + Math.mulDivDown(y1 - y0, tenor - x0, x1 - x0);
                } else {
                    return y0 - Math.mulDivDown(y0 - y1, tenor - x0, x1 - x0);
                }
            } else {
                return y0;
            }
        }
    }
}
