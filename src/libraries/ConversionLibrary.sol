// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

library ConversionLibrary {
    function amountToWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        // @audit-info The protocol does not support tokens with more than 18 decimals
        return amount * 10 ** (18 - decimals);
    }

    function wadToAmountDown(uint256 wad, uint8 decimals) internal pure returns (uint256) {
        // @audit-info The protocol does not support tokens with more than 18 decimals
        return wad / 10 ** (18 - decimals);
    }
}
