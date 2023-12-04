// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {VaultLibrary} from "@src/libraries/VaultLibrary.sol";

contract VaultLibraryTest is Test {
    function test_VaultLibrary_valueToWad_18_decimals() public {
        uint256 value = 1e18;
        uint256 decimals = 18;

        uint256 wad = VaultLibrary.valueToWad(value, decimals);
        assertEq(wad, value);
    }

    function test_VaultLibrary_valueToWad_18_decimals(uint256 value) public {
        uint256 decimals = 18;

        uint256 wad = VaultLibrary.valueToWad(value, decimals);
        assertEq(wad, value);
    }

    function test_VaultLibrary_valueToWad_lt_18() public {
        uint256 value = 1e6;
        uint256 decimals = 6;

        uint256 wad = VaultLibrary.valueToWad(value, decimals);
        assertEq(wad, 1e18);
    }

    function test_VaultLibrary_valueToWad_lt_18(uint256 value) public {
        value = bound(value, 0, type(uint256).max / 1e18);
        uint256 decimals = 6;

        uint256 wad = VaultLibrary.valueToWad(value, decimals);
        assertEq(wad, value * 1e12);
    }

    function test_VaultLibrary_valueToWad_gt_18() public {
        uint256 value = 1e24;
        uint256 decimals = 24;

        vm.expectRevert();
        VaultLibrary.valueToWad(value, decimals);
    }

    function test_VaultLibrary_valueToWad_gt_18(uint256 value) public {
        uint256 decimals = 24;

        vm.expectRevert();
        VaultLibrary.valueToWad(value, decimals);
    }
}
