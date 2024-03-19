// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Test} from "forge-std/Test.sol";

contract ConversionLibraryTest is Test {
    function test_ConversionLibrary_amountToWad_18_decimals() public {
        uint256 amount = 1e6;
        uint8 decimals = 18;

        uint256 wad = ConversionLibrary.amountToWad(amount, decimals);
        assertEq(wad, amount);
    }

    function testFuzz_ConversionLibrary_amountToWad_18_decimals(uint256 amount) public {
        uint8 decimals = 18;

        uint256 wad = ConversionLibrary.amountToWad(amount, decimals);
        assertEq(wad, amount);
    }

    function test_ConversionLibrary_amountToWad_lt_18() public {
        uint256 amount = 1e6;
        uint8 decimals = 6;

        uint256 wad = ConversionLibrary.amountToWad(amount, decimals);
        assertEq(wad, 1e18);
    }

    function testFuzz_ConversionLibrary_amountToWad_lt_18(uint256 amount) public {
        amount = bound(amount, 0, type(uint256).max / 1e18);
        uint8 decimals = 6;

        uint256 wad = ConversionLibrary.amountToWad(amount, decimals);
        assertEq(wad, amount * 1e12);
    }

    function test_ConversionLibrary_amountToWad_gt_18() public {
        uint256 amount = 1e24;
        uint8 decimals = 24;

        vm.expectRevert();
        ConversionLibrary.amountToWad(amount, decimals);
    }

    function testFuzz_ConversionLibrary_amountToWad_gt_18(uint256 amount) public {
        uint8 decimals = 24;

        vm.expectRevert();
        ConversionLibrary.amountToWad(amount, decimals);
    }
}
