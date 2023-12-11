// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

uint256 constant PERCENT = 1e4;

library MathLibrary {
    function valueToWad(uint256 value, uint256 decimals) public pure returns (uint256) {
        // @audit protocol does not support tokens with more than 18 decimals
        return value * 10 ** (18 - decimals);
    }
}
