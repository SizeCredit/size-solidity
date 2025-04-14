// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Math} from "@src/market/libraries/Math.sol";

import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

import {ChainlinkPriceFeed} from "@src/oracle/adapters/ChainlinkPriceFeed.sol";
import {ChainlinkSequencerUptimeFeed} from "@src/oracle/adapters/ChainlinkSequencerUptimeFeed.sol";
import {UniswapV3PriceFeed} from "@src/oracle/adapters/UniswapV3PriceFeed.sol";
import {PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

/// @title PriceFeedChainlinkUniswapV3TWAPx2
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, scaled to 18 decimals,
///           using Chainlink, with fallback using two Uniswap V3 TWAPs
/// @dev `decimals` must be 18 to comply with Size contracts
contract PriceFeedChainlinkUniswapV3TWAPx2 is IPriceFeedV1_5_2 {
    /* solhint-disable */
    uint256 public constant decimals = 18;
    ChainlinkPriceFeed public immutable chainlinkPriceFeed;
    UniswapV3PriceFeed public immutable uniswapV3BasePriceFeed;
    UniswapV3PriceFeed public immutable uniswapV3QuotePriceFeed;
    /* solhint-enable */

    constructor(
        PriceFeedParams memory chainlinkPriceFeedParams,
        PriceFeedParams memory uniswapV3BasePriceFeedParams,
        PriceFeedParams memory uniswapV3QuotePriceFeedParams
    ) {
        chainlinkPriceFeed = new ChainlinkPriceFeed(
            decimals,
            chainlinkPriceFeedParams.baseAggregator,
            chainlinkPriceFeedParams.quoteAggregator,
            chainlinkPriceFeedParams.baseStalePriceInterval,
            chainlinkPriceFeedParams.quoteStalePriceInterval
        );
        uniswapV3BasePriceFeed = new UniswapV3PriceFeed(
            decimals,
            uniswapV3BasePriceFeedParams.baseToken,
            uniswapV3BasePriceFeedParams.quoteToken,
            uniswapV3BasePriceFeedParams.uniswapV3Pool,
            uniswapV3BasePriceFeedParams.twapWindow,
            uniswapV3BasePriceFeedParams.averageBlockTime
        );
        uniswapV3QuotePriceFeed = new UniswapV3PriceFeed(
            decimals,
            uniswapV3QuotePriceFeedParams.baseToken,
            uniswapV3QuotePriceFeedParams.quoteToken,
            uniswapV3QuotePriceFeedParams.uniswapV3Pool,
            uniswapV3QuotePriceFeedParams.twapWindow,
            uniswapV3QuotePriceFeedParams.averageBlockTime
        );
    }

    function getPrice() external view override returns (uint256) {
        try chainlinkPriceFeed.getPrice() returns (uint256 price) {
            return price;
        } catch {
            uint256 basePrice = uniswapV3BasePriceFeed.getPrice();
            uint256 quotePrice = uniswapV3QuotePriceFeed.getPrice();

            return Math.mulDivDown(basePrice, quotePrice, 10 ** decimals);
        }
    }

    function description() external view override returns (string memory) {
        return string.concat(
            "PriceFeedChainlinkUniswapV3TWAPx2 | ((",
            chainlinkPriceFeed.baseAggregator().description(),
            ") / (",
            chainlinkPriceFeed.quoteAggregator().description(),
            ")) (Chainlink) | ((",
            uniswapV3BasePriceFeed.baseToken().symbol(),
            " / ",
            uniswapV3BasePriceFeed.quoteToken().symbol(),
            ") * (",
            uniswapV3QuotePriceFeed.baseToken().symbol(),
            " / ",
            uniswapV3QuotePriceFeed.quoteToken().symbol(),
            ")) (Uniswap v3 TWAP)"
        );
    }
}
