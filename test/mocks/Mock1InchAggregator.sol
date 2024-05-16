// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./PriceFeedMock.sol";

contract Mock1InchAggregator {
    PriceFeedMock public priceFeed;

    event Swap(
        address indexed fromToken,
        address indexed toToken,
        uint256 amount,
        uint256 minReturn,
        bytes data
    );

    event Debug(string message, uint256 value);

    constructor(address _priceFeed) {
        priceFeed = PriceFeedMock(_priceFeed);
    }

    // Note: This function only calculates swap amounts correctly for Base -> Quote token of the priceFeed
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
        emit Debug("Before transferFrom", amount);
        require(IERC20(fromToken).transferFrom(msg.sender, address(this), amount), "Transfer of fromToken failed");
        emit Debug("After transferFrom", amount);

        // Calculate the amount of toToken to return based on the price feed
        emit Debug("Before getPrice", 0);
        uint256 price = priceFeed.getPrice();
        emit Debug("After getPrice", price);
        uint256 toTokenAmount = (amount * price) / 1e12; // Adjust for WETH/USDC decimals 
        emit Debug("Calculated toTokenAmount", toTokenAmount);

        // Ensure the aggregator has enough toToken balance
        emit Debug("Before balanceOf", IERC20(toToken).balanceOf(address(this)));
        require(IERC20(toToken).balanceOf(address(this)) >= toTokenAmount, "Insufficient toToken balance");
        emit Debug("After balanceOf", IERC20(toToken).balanceOf(address(this)));

        // Transfer the calculated toToken amount to the caller
        emit Debug("Before transfer", toTokenAmount);
        require(IERC20(toToken).transfer(msg.sender, toTokenAmount), "Transfer of toToken failed");
        emit Debug("After transfer", toTokenAmount);

        return toTokenAmount;
    }
}