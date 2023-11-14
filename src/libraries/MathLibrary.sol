// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

uint256 constant PERCENT = 1e18;

library Math {
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }
}
