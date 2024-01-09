// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {console2 as console} from "forge-std/console2.sol";

uint256 constant PERCENT = 1e18;

library Math {
    function amountToWad(uint256 amount, uint256 decimals) public pure returns (uint256) {
        // @audit-info The protocol does not support tokens with more than 18 decimals
        return amount * 10 ** (18 - decimals);
    }

    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return FixedPointMathLib.min(a, b);
    }

    function min(uint256 a, uint256 b, uint256 c) public pure returns (uint256) {
        uint256 minAB = FixedPointMathLib.min(a, b);
        return FixedPointMathLib.min(minAB, c);
    }

    function mulDivUp(uint256 x, uint256 y, uint256 z) public pure returns (uint256) {
        return FixedPointMathLib.mulDivUp(x, y, z);
    }

    function mulDivDown(uint256 x, uint256 y, uint256 z) public pure returns (uint256) {
        return FixedPointMathLib.mulDiv(x, y, z);
    }

    function binarySearch(uint256[] memory array, uint256 value) public view returns (uint256 low, uint256 high) {
        low = 0;
        high = array.length - 1;
        if (value < array[low] || value > array[high]) {
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
