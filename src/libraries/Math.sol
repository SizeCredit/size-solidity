// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

uint256 constant PERCENT = 1e18;

// @audit Check rounding direction of all `FixedPointMath.mulDiv{Up,Down}`

/// @title Math
library Math {
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return FixedPointMathLib.min(a, b);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return FixedPointMathLib.max(a, b);
    }

    function min(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        return FixedPointMathLib.min(FixedPointMathLib.min(a, b), c);
    }

    function mulDivUp(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return FixedPointMathLib.mulDivUp(x, y, z);
    }

    function mulDivDown(uint256 x, uint256 y, uint256 z) internal pure returns (uint256) {
        return FixedPointMathLib.mulDiv(x, y, z);
    }

    function mulDiv(int256 x, int256 y, int256 z) internal pure returns (int256) {
        return x * y / z;
    }

    function powWadWad(uint256 wad1, uint256 wad2) internal pure returns (uint256) {
        return SafeCast.toUint256(FixedPointMathLib.powWad(SafeCast.toInt256(wad1), SafeCast.toInt256(wad2)));
    }

    function ratePerMaturityToLinearAPR(int256 rate, uint256 maturity) internal pure returns (int256) {
        return mulDiv(rate, 365 days, SafeCast.toInt256(maturity));
    }

    function ratePerMaturityToLinearAPR(uint256 rate, uint256 maturity) internal pure returns (uint256) {
        return mulDivDown(rate, 365 days, maturity);
    }

    function linearAPRToRatePerMaturity(int256 rate, uint256 maturity) internal pure returns (int256) {
        return mulDiv(rate, SafeCast.toInt256(maturity), 365 days);
    }

    function compoundAPRToRatePerMaturity(uint256 rate, uint256 maturity) internal pure returns (uint256) {
        return powWadWad(PERCENT + rate, mulDivDown(PERCENT, maturity, 365 days)) - PERCENT;
    }

    function binarySearch(uint256[] memory array, uint256 value) internal pure returns (uint256 low, uint256 high) {
        low = 0;
        high = array.length - 1;
        if (value < array[low] || value > array[high]) {
            // @audit-info Covered in test_Math_binarySearch_not_found
            return (type(uint256).max, type(uint256).max);
        }
        while (low <= high) {
            uint256 mid = (low + high) / 2;
            if (array[mid] == value) {
                return (mid, mid);
            } else if (array[mid] < value) {
                low = mid + 1;
            } else {
                high = mid - 1;
            }
        }
        return (high, low);
    }
}
