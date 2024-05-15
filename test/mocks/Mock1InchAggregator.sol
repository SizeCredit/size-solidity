// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract Mock1InchAggregator {
    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata data
    ) external payable returns (uint256 returnAmount) {
        // Mock swap logic
        return amount; // For simplicity, return the same amount
    }
}