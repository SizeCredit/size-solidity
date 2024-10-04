// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract SimplePool {
    uint256 private index;
    uint256 private startTime;

    uint256 private constant SCALE = 1e27;
    uint256 private constant APY = 0.05e27;

    constructor(uint256 _index) {
        index = _index;
        startTime = block.timestamp;
    }

    function getReserveNormalizedIncome(address) public view returns (uint256) {
        uint256 timeElapsed = block.timestamp - startTime;
        uint256 growthFactor = SCALE + ((APY * timeElapsed) / 365 days);
        return (index * growthFactor) / SCALE;
    }
}
