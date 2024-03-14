// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// @audit-info The protocol does not support tokens with more than 18 decimals

/// @title ConversionLibrary
library ConversionLibrary {
    function amountToWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return amount * 10 ** (18 - decimals);
    }

    function wadToAmountDown(uint256 wad, uint8 decimals) internal pure returns (uint256) {
        // @audit-info Covered in test_ConversionLibrary_wadToAmountDown*
        return wad / 10 ** (18 - decimals);
    }

    function rayToWadDown(uint256 ray) internal pure returns (uint256) {
        // @audit-info Covered in test_ConversionLibrary_rayToWadDown
        return ray / 1e9;
    }
}
