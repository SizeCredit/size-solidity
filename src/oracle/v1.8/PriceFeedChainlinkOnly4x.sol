// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {PriceFeedChainlinkMul} from "@src/oracle/v1.8/PriceFeedChainlinkMul.sol";

/// @title PriceFeedChainlinkOnly4x
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///         by calculating `(base * intermediate1) / (quote * intermediate2)`, using Chainlink only.
/// @dev `decimals` must be 18 to comply with Size contracts
///      Only networks without a sequencer are supported.
contract PriceFeedChainlinkOnly4x is IPriceFeed {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    PriceFeedChainlinkMul public immutable baseToIntermediate1;
    PriceFeedChainlinkMul public immutable quoteToIntermediate2;
    /* solhint-enable */

    constructor(
        AggregatorV3Interface baseAggregator,
        AggregatorV3Interface intermediate1Aggregator,
        AggregatorV3Interface quoteAggregator,
        AggregatorV3Interface intermediate2Aggregator,
        uint256 baseStalePriceInterval,
        uint256 intermediate1StalePriceInterval,
        uint256 quoteStalePriceInterval,
        uint256 intermediate2StalePriceInterval
    ) {
        baseToIntermediate1 = new PriceFeedChainlinkMul(
            decimals, baseAggregator, intermediate1Aggregator, baseStalePriceInterval, intermediate1StalePriceInterval
        );
        quoteToIntermediate2 = new PriceFeedChainlinkMul(
            decimals, quoteAggregator, intermediate2Aggregator, quoteStalePriceInterval, intermediate2StalePriceInterval
        );
    }

    function getPrice() external view override returns (uint256) {
        uint256 baseToIntermediate1Price = baseToIntermediate1.getPrice();
        uint256 quoteToIntermediate2Price = quoteToIntermediate2.getPrice();
        return Math.mulDivDown(baseToIntermediate1Price, quoteToIntermediate2Price, 10 ** decimals);
    }
}
