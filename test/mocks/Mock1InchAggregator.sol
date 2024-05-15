// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

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

        // Transfer the fromToken from the caller to the aggregator
        require(IERC20(fromToken).transferFrom(msg.sender, address(this), amount), "Transfer of fromToken failed");
        // Mock swap logic: transfer the contract's full balance of toToken to the caller
        uint256 toTokenBalance = IERC20(toToken).balanceOf(address(this));
        require(IERC20(toToken).transfer(msg.sender, toTokenBalance), "Transfer of toToken failed");

        return amount; // For simplicity, return the same amount
    }
}