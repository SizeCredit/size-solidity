// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PriceFeed} from "@src/oracle/PriceFeed.sol";

library PriceFeedFactoryLibrary {
    function createPriceFeed(
        address sequencerUptimeFeed,
        address underlyingCollateralTokenAggregator,
        address underlyingBorrowTokenAggregator,
        uint256 underlyingCollateralTokenHeartbeat,
        uint256 underlyingBorrowTokenHeartbeat
    ) external returns (PriceFeed priceFeed) {
        priceFeed = new PriceFeed(
            sequencerUptimeFeed,
            underlyingCollateralTokenAggregator,
            underlyingBorrowTokenAggregator,
            underlyingCollateralTokenHeartbeat,
            underlyingBorrowTokenHeartbeat
        );
    }
}
