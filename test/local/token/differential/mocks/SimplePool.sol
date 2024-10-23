// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract SimplePool {
    uint256 private constant SCALE = 1e27;

    constructor() {}

    function getReserveNormalizedIncome(address) public pure returns (uint256) {
        return SCALE;
    }
}
