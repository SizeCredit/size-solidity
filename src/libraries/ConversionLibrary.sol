// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// @audit-info The protocol does not support tokens with more than 18 decimals

/// @title ConversionLibrary
library ConversionLibrary {
    function amountToWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return amount * 10 ** (18 - decimals);
    }
}
