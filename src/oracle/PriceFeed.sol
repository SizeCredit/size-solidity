// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ChainlinkSequencerUptimeFeed} from "@src/oracle/adapters/ChainlinkSequencerUptimeFeed.sol";
import {ChainlinkPriceFeed} from "@src/oracle/adapters/ChainlinkPriceFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/adapters/UniswapV3PriceFeed.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title PriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice  price feeds from Chainlink and Uniswap V3
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals
/// @dev The contract uses Chainlink as a primary oracle. If Chainlink is down, uses Uniswap V3 as a fallback oracle
contract PriceFeed is IPriceFeed {
    uint256 public constant decimals = 18;
    ChainlinkSequencerUptimeFeed public immutable chainlinkSequencerUptimeFeed;
    ChainlinkPriceFeed public immutable chainlinkPriceFeed;
    UniswapV3PriceFeed public immutable uniswapV3PriceFeed;
    constructor(
        address _sequencerUptimeFeed,
        address _baseAggregator,
        address _quoteAggregator,
        uint256 _baseStalePriceInterval,
        uint256 _quoteStalePriceInterval
    ) {
        chainlinkSequencerUptimeFeed = new ChainlinkSequencerUptimeFeed(
            _sequencerUptimeFeed
        );
        chainlinkPriceFeed = new ChainlinkPriceFeed(
            decimals,
            _baseAggregator,
            _quoteAggregator,
            _baseStalePriceInterval,
            _quoteStalePriceInterval
        );
        uniswapV3PriceFeed = new UniswapV3PriceFeed(decimals);
    }

    function getPrice() external view override returns (uint256) {
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();
 
        try chainlinkPriceFeed.getPrice() returns (uint256 price) {
            return price;
        } catch {
            return uniswapV3PriceFeed.getPrice();
        }
    }
}
