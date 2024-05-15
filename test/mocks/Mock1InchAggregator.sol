// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract Mock1InchAggregator {
    event Swap(
        address indexed fromToken,
        address indexed toToken,
        uint256 amount,
        uint256 minReturn,
        bytes data
    );

    function swap(
        address fromToken,
        address toToken,
        uint256 amount,
        uint256 minReturn,
        bytes calldata data
    ) external payable returns (uint256 returnAmount) {
        // Log the parameters to avoid compiler warnings
        emit Swap(fromToken, toToken, amount, minReturn, data);

        // Mock swap logic
        return amount; // For simplicity, return the same amount
    }
}