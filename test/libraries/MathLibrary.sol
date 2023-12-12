// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {MathLibrary} from "@src/libraries/MathLibrary.sol";

contract MathLibraryTest is Test {
    function test_MathLibrary_valueToWad_18_decimals() public {
        uint256 amount = 1e18;
        uint256 decimals = 18;

        uint256 wad = MathLibrary.amountToWad(amount, decimals);
        assertEq(wad, amount);
    }

    function testFuzz_MathLibrary_valueToWad_18_decimals(uint256 amount) public {
        uint256 decimals = 18;

        uint256 wad = MathLibrary.amountToWad(amount, decimals);
        assertEq(wad, amount);
    }

    function test_MathLibrary_valueToWad_lt_18() public {
        uint256 amount = 1e6;
        uint256 decimals = 6;

        uint256 wad = MathLibrary.amountToWad(amount, decimals);
        assertEq(wad, 1e18);
    }

    function testFuzz_MathLibrary_valueToWad_lt_18(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max / 1e18);
        uint256 decimals = 6;

        uint256 wad = MathLibrary.amountToWad(amount, decimals);
        assertEq(wad, amount * 1e12);
    }

    function test_MathLibrary_valueToWad_gt_18() public {
        uint256 amount = 1e24;
        uint256 decimals = 24;

        vm.expectRevert();
        MathLibrary.amountToWad(amount, decimals);
    }

    function testFuzz_MathLibrary_valueToWad_gt_18(uint256 amount) public {
        uint256 decimals = 24;

        vm.expectRevert();
        MathLibrary.amountToWad(amount, decimals);
    }
}
