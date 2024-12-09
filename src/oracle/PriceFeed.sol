// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPriceFeedV1_5} from "@src/oracle/IPriceFeedV1_5.sol";
import {ChainlinkPriceFeed} from "@src/oracle/adapters/ChainlinkPriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/adapters/ChainlinkSequencerUptimeFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/adapters/UniswapV3PriceFeed.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

struct PriceFeedParams {
    IUniswapV3Factory uniswapV3Factory;
    IUniswapV3Pool pool;
    uint32 twapWindow;
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
contract PriceFeed is IPriceFeedV1_5 {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    ChainlinkSequencerUptimeFeed public immutable chainlinkSequencerUptimeFeed;
    ChainlinkPriceFeed public immutable chainlinkPriceFeed;
    UniswapV3PriceFeed public immutable uniswapV3PriceFeed;
    /* solhint-enable */

    constructor(PriceFeedParams memory _priceFeedParams) {
        chainlinkSequencerUptimeFeed = new ChainlinkSequencerUptimeFeed(_priceFeedParams.sequencerUptimeFeed);
        chainlinkPriceFeed = new ChainlinkPriceFeed(
            decimals,
            _priceFeedParams.baseAggregator,
            _priceFeedParams.quoteAggregator,
            _priceFeedParams.baseStalePriceInterval,
            _priceFeedParams.quoteStalePriceInterval
        );
        uniswapV3PriceFeed = new UniswapV3PriceFeed(
            decimals,
            _priceFeedParams.baseToken,
            _priceFeedParams.quoteToken,
            _priceFeedParams.uniswapV3Factory,
            _priceFeedParams.pool,
            _priceFeedParams.twapWindow
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

    function base() external view override returns (AggregatorV3Interface) {
        return chainlinkPriceFeed.baseAggregator();
    }

    function quote() external view override returns (AggregatorV3Interface) {
        return chainlinkPriceFeed.quoteAggregator();
    }

    function baseStalePriceInterval() external view override returns (uint256) {
        return chainlinkPriceFeed.baseStalePriceInterval();
    }

    function quoteStalePriceInterval() external view override returns (uint256) {
        return chainlinkPriceFeed.quoteStalePriceInterval();
    }
}
