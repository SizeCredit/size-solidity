// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./PriceFeedMock.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Mock1InchAggregator {
    PriceFeedMock public priceFeed;

    event Swap(address indexed fromToken, address indexed toToken, uint256 amount, uint256 minReturn, bytes data);

    constructor(address _priceFeed) {
        priceFeed = PriceFeedMock(_priceFeed);
    }

    // Note: This function only calculates swap amounts correctly for Base -> Quote token of the priceFeed
    function swap(address fromToken, address toToken, uint256 amount, uint256 minReturn, bytes calldata data)
        external
        payable
        returns (uint256 returnAmount)
    {
        // Log the parameters to avoid compiler warnings
        emit Swap(fromToken, toToken, amount, minReturn, data);

        // Transfer the fromToken from the caller to the aggregator
        require(IERC20(fromToken).transferFrom(msg.sender, address(this), amount), "Transfer of fromToken failed");

        // Calculate the amount of toToken to return based on the price feed
        uint256 price = priceFeed.getPrice();
        uint256 toTokenAmount = (amount * price) / 1e12; // Adjust for WETH/USDC decimals

        // Ensure the aggregator has enough toToken balance
        require(IERC20(toToken).balanceOf(address(this)) >= toTokenAmount, "Insufficient toToken balance");

        // Transfer the calculated toToken amount to the caller
        require(IERC20(toToken).transfer(msg.sender, toTokenAmount), "Transfer of toToken failed");

        return toTokenAmount;
    }
}
