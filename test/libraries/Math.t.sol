// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Math} from "@src/market/libraries/Math.sol";

import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";
import {Test} from "forge-std/Test.sol";

contract MathTest is Test, AssertsHelper {
    function test_Math_mulDivUp() public pure {
        assertEq(Math.mulDivUp(3, 5, 4), 4);
        assertEq(Math.mulDivUp(4, 5, 4), 5);
    }

    function test_Math_mulDivDown() public pure {
        assertEq(Math.mulDivDown(3, 5, 4), 3);
        assertEq(Math.mulDivDown(4, 5, 4), 5);
    }

    function test_Math_binarySearch_two() public pure {
        uint256[] memory array = new uint256[](2);
        array[0] = 86400;
        array[1] = 259200;
        uint256 needle = 172800;
        uint256 low;
        uint256 high;
        (low, high) = Math.binarySearch(array, needle);
        assertEq(low, 0);
        assertEq(high, 1);
    }

    function test_Math_binarySearch_found() public pure {
        uint256[] memory array = new uint256[](5);
        array[0] = 10;
        array[1] = 20;
        array[2] = 30;
        array[3] = 40;
        array[4] = 50;
        uint256 low;
        uint256 high;
        for (uint256 i = 0; i < array.length; i++) {
            (low, high) = Math.binarySearch(array, array[i]);
            assertEq(low, i);
            assertEq(high, i);
        }
    }

    function test_Math_binarySearch_not_found() public pure {
        uint256[] memory array = new uint256[](5);
        array[0] = 10;
        array[1] = 20;
        array[2] = 30;
        array[3] = 40;
        array[4] = 50;
        uint256 low;
        uint256 high;
        (low, high) = Math.binarySearch(array, 0);
        assertEq(low, type(uint256).max);
        assertEq(high, type(uint256).max);
        (low, high) = Math.binarySearch(array, 13);
        assertEq(low, 0);
        assertEq(high, 1);
        (low, high) = Math.binarySearch(array, 17);
        assertEq(low, 0);
        assertEq(high, 1);
        (low, high) = Math.binarySearch(array, 21);
        assertEq(low, 1);
        assertEq(high, 2);
        (low, high) = Math.binarySearch(array, 29);
        assertEq(low, 1);
        assertEq(high, 2);
        (low, high) = Math.binarySearch(array, 32);
        assertEq(low, 2);
        assertEq(high, 3);
        (low, high) = Math.binarySearch(array, 37);
        assertEq(low, 2);
        assertEq(high, 3);
        (low, high) = Math.binarySearch(array, 42);
        assertEq(low, 3);
        assertEq(high, 4);
        (low, high) = Math.binarySearch(array, 45);
        assertEq(low, 3);
        assertEq(high, 4);
        (low, high) = Math.binarySearch(array, 51);
        assertEq(low, type(uint256).max);
        assertEq(high, type(uint256).max);
    }

    function test_Math_aprToRatePerTenor() public pure {
        // 1% APY (linear interest) is 0.082% over the period of 30 days
        assertEqApprox((Math.aprToRatePerTenor(uint256(0.01e18), 30 days)), 0.000821917808219178e18, 1);
    }

    /// @custom:halmos --loop 5
    function check_Math_binarySearch(uint256[] memory array, uint256 value) public pure {
        // array is strictly increasing
        for (uint256 i = 0; i < array.length - 1; i++) {
            vm.assume(array[i] < array[i + 1]);
        }
        (uint256 low, uint256 high) = Math.binarySearch(array, value);
        if (value < array[0] || value > array[array.length - 1]) {
            // not found
            assertEq(low, type(uint256).max, "not found");
            assertEq(high, type(uint256).max, "not found");
        } else {
            assertGe(low, 0, "low is within bounds");
            assertLe(low, array.length - 1, "low is within bounds");

            assertGe(high, 0, "high is within bounds");
            assertLe(high, array.length - 1, "high is within bounds");

            assertLe(low, high, "low <= high");
            assertLe(low, high + 1, "low <= high + 1");

            assertLe(array[low], value, "array[low] <= value <= array[high]");
            assertLe(value, array[high], "array[low] <= value <= array[high]");

            if (value == array[low]) {
                assertEq(low, high, "low == high if the value is in the array");
            }
        }
    }
}
