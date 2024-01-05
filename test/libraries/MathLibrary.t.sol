// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/MathLibrary.sol";
import {Test} from "forge-std/Test.sol";

contract MathTest is Test {
    function test_Math_valueToWad_18_decimals() public {
        uint256 amount = 1e18;
        uint256 decimals = 18;

        uint256 wad = Math.amountToWad(amount, decimals);
        assertEq(wad, amount);
    }

    function testFuzz_Math_valueToWad_18_decimals(uint256 amount) public {
        uint256 decimals = 18;

        uint256 wad = Math.amountToWad(amount, decimals);
        assertEq(wad, amount);
    }

    function test_Math_valueToWad_lt_18() public {
        uint256 amount = 1e6;
        uint256 decimals = 6;

        uint256 wad = Math.amountToWad(amount, decimals);
        assertEq(wad, 1e18);
    }

    function testFuzz_Math_valueToWad_lt_18(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max / 1e18);
        uint256 decimals = 6;

        uint256 wad = Math.amountToWad(amount, decimals);
        assertEq(wad, amount * 1e12);
    }

    function test_Math_valueToWad_gt_18() public {
        uint256 amount = 1e24;
        uint256 decimals = 24;

        vm.expectRevert();
        Math.amountToWad(amount, decimals);
    }

    function testFuzz_Math_valueToWad_gt_18(uint256 amount) public {
        uint256 decimals = 24;

        vm.expectRevert();
        Math.amountToWad(amount, decimals);
    }

    function test_Math_min() public {
        assertEq(Math.min(4, 5, 6), 4);
        assertEq(Math.min(4, 6, 5), 4);
        assertEq(Math.min(5, 4, 6), 4);
        assertEq(Math.min(5, 6, 4), 4);
        assertEq(Math.min(6, 4, 5), 4);
        assertEq(Math.min(6, 5, 4), 4);
    }

    function test_Math_mulDivUp() public {
        assertEq(Math.mulDivUp(3, 5, 4), 4);
        assertEq(Math.mulDivUp(4, 5, 4), 5);
    }

    function test_Math_mulDivDown() public {
        assertEq(Math.mulDivDown(3, 5, 4), 3);
        assertEq(Math.mulDivDown(4, 5, 4), 5);
    }
}
