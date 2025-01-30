// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";
import {ChainlinkPriceFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkPriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/v1.5.1/adapters/ChainlinkSequencerUptimeFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/v1.5.1/adapters/UniswapV3PriceFeed.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct PriceFeedParams {
    IUniswapV3Pool uniswapV3Pool;
    uint32 twapWindow;
    uint32 averageBlockTime;
    IERC20Metadata baseToken;
    IERC20Metadata quoteToken;
    AggregatorV3Interface baseAggregator;
    AggregatorV3Interface quoteAggregator;
    uint256 baseStalePriceInterval;
    uint256 quoteStalePriceInterval;
    AggregatorV3Interface sequencerUptimeFeed;
}

/// @title PriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///         using Chainlink as a primary oracle and Uniswap V3 as a fallback oracle
/// @dev `decimals` must be 18 to comply with Size contracts
///      `sequencerUptimeFeed` can be null for unsupported networks
///      In case the sequencer is down, `getPrice` reverts (see `ChainlinkSequencerUptimeFeed`)
contract PriceFeed is IPriceFeed {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    ChainlinkSequencerUptimeFeed public immutable chainlinkSequencerUptimeFeed;
    ChainlinkPriceFeed public immutable chainlinkPriceFeed;
    UniswapV3PriceFeed public immutable uniswapV3PriceFeed;
    /* solhint-enable */

    constructor(PriceFeedParams memory priceFeedParams) {
        chainlinkSequencerUptimeFeed = new ChainlinkSequencerUptimeFeed(priceFeedParams.sequencerUptimeFeed);
        chainlinkPriceFeed = new ChainlinkPriceFeed(
            decimals,
            priceFeedParams.baseAggregator,
            priceFeedParams.quoteAggregator,
            priceFeedParams.baseStalePriceInterval,
            priceFeedParams.quoteStalePriceInterval
        );
        uniswapV3PriceFeed = new UniswapV3PriceFeed(
            decimals,
            priceFeedParams.baseToken,
            priceFeedParams.quoteToken,
            priceFeedParams.uniswapV3Pool,
            priceFeedParams.twapWindow,
            priceFeedParams.averageBlockTime
        );
    }

    function getPrice() external view override returns (uint256) {
        chainlinkSequencerUptimeFeed.validateSequencerIsUp();

        try chainlinkPriceFeed.getPrice() returns (uint256 price) {
            return price;
        } catch {
            return uniswapV3PriceFeed.getPrice();
        }
    }

    function base() external view returns (AggregatorV3Interface) {
        return chainlinkPriceFeed.baseAggregator();
    }

    function quote() external view returns (AggregatorV3Interface) {
        return chainlinkPriceFeed.quoteAggregator();
    }

    function baseStalePriceInterval() external view returns (uint256) {
        return chainlinkPriceFeed.baseStalePriceInterval();
    }

    function quoteStalePriceInterval() external view returns (uint256) {
        return chainlinkPriceFeed.quoteStalePriceInterval();
    }
}
