// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PriceFeed} from "@src/oracle/PriceFeed.sol";

library PriceFeedFactoryLibrary {
    function createPriceFeed(
        address underlyingCollateralTokenAggregator,
        address underlyingBorrowTokenAggregator,
        address sequencerUptimeFeed,
        uint256 underlyingCollateralTokenHeartbeat,
        uint256 underlyingBorrowTokenHeartbeat
    ) external returns (PriceFeed priceFeed) {
        priceFeed = new PriceFeed(
            underlyingCollateralTokenAggregator,
            underlyingBorrowTokenAggregator,
            sequencerUptimeFeed,
            underlyingCollateralTokenHeartbeat,
            underlyingBorrowTokenHeartbeat
        );
    }
}
