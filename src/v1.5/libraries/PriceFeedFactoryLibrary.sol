// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

library PriceFeedFactoryLibrary {
    function createPriceFeed(PriceFeedParams memory _priceFeedParams) external returns (PriceFeed priceFeed) {
        priceFeed = new PriceFeed(_priceFeedParams);
    }
}
