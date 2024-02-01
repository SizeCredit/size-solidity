// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/Math.sol";

// @audit-info The protocol does not support tokens with more than 18 decimals
library ConversionLibrary {
    function amountToWad(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return amount * 10 ** (18 - decimals);
    }

    function wadToAmountDown(uint256 wad, uint8 decimals) internal pure returns (uint256) {
        return wad / 10 ** (18 - decimals);
    }

    function wadToAmountUp(uint256 wad, uint8 decimals) internal pure returns (uint256) {
        return Math.mulDivUp(wad, 10 ** decimals, 10 ** 18);
    }

    function rayToWadDown(uint256 ray) internal pure returns (uint256) {
        return ray / 1e9;
    }

}
