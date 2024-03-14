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

    function test_ConversionLibrary_wadToAmountDown_18_decimals() public {
        uint256 amount = 1e6;
        uint8 decimals = 18;

        uint256 wad = ConversionLibrary.wadToAmountDown(amount, decimals);
        assertEq(wad, amount);
    }

    function testFuzz_ConversionLibrary_wadToAmountDown_18_decimals(uint256 amount) public {
        uint8 decimals = 18;

        uint256 wad = ConversionLibrary.wadToAmountDown(amount, decimals);
        assertEq(wad, amount);
    }

    function test_ConversionLibrary_wadToAmountDown_lt_18() public {
        uint256 amount = 1e18;
        uint8 decimals = 6;

        uint256 wad = ConversionLibrary.wadToAmountDown(amount, decimals);
        assertEq(wad, 1e6);
    }

    function testFuzz_ConversionLibrary_wadToAmountDown_lt_18(uint256 amount) public {
        uint8 decimals = 6;

        uint256 wad = ConversionLibrary.wadToAmountDown(amount, decimals);
        assertEq(wad, amount / 1e12);
    }

    function test_ConversionLibrary_wadToAmountDown_gt_18() public {
        uint256 amount = 1e24;
        uint8 decimals = 24;

        vm.expectRevert();
        ConversionLibrary.wadToAmountDown(amount, decimals);
    }

    function testFuzz_ConversionLibrary_wadToAmountDown_gt_18(uint256 amount) public {
        uint8 decimals = 24;

        vm.expectRevert();
        ConversionLibrary.wadToAmountDown(amount, decimals);
    }

    function test_ConversionLibrary_rayToWadDown() public {
        assertEq(ConversionLibrary.rayToWadDown(1e27), 1e18);
        assertEq(ConversionLibrary.rayToWadDown(1e27 + 1), 1e18);
        assertEq(ConversionLibrary.rayToWadDown(2e27), 2e18);
        assertEq(ConversionLibrary.rayToWadDown(1.5e27), 1.5e18);
        assertEq(ConversionLibrary.rayToWadDown(3.141592653589793115997963469e27), 3.141592653589793115e18);
    }
}
