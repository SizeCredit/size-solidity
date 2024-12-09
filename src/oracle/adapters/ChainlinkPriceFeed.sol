// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math} from "@src/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title ChainlinkPriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice If `baseAggregator` and `quoteAggregator` are equal, the result is the price of the aggregator without any intermediate asset (2)
/// @dev The price is calculated as `base / quote`
///      Example configuration (1)
///         _base: ETH/USD feed
///         _quote: USDC/USD feed
///         _baseStalePriceInterval: 3600 seconds (https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd)
///         _quoteStalePriceInterval: 86400 seconds (https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd)
///         answer: ETH/USDC in 1e18
///         Note: _base and _quote must have the same number of decimals
///         Note: _base and _quote must have the same intermediate asset (in this example, USD)
///      Example configuration (2)
///         _base: STETH/ETH feed
///         _quote: STETH/ETH feed
///         _baseStalePriceInterval: 86400 seconds (https://data.chain.link/feeds/base/base/steth-eth)
///         _quoteStalePriceInterval: 86400 seconds (https://data.chain.link/feeds/base/base/steth-eth)
///         answer: STETH/ETH in 1e18
contract ChainlinkPriceFeed is IPriceFeed {
    /* solhint-disable */
    uint256 public immutable decimals = 18;
    AggregatorV3Interface public immutable baseAggregator;
    AggregatorV3Interface public immutable quoteAggregator;
    uint256 public immutable baseStalePriceInterval;
    uint256 public immutable quoteStalePriceInterval;
    /* solhint-enable */

    constructor(
        uint256 _decimals,
        AggregatorV3Interface _baseAggregator,
        AggregatorV3Interface _quoteAggregator,
        uint256 _baseStalePriceInterval,
        uint256 _quoteStalePriceInterval
    ) {
        if (address(_baseAggregator) == address(0) || address(_quoteAggregator) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        if (_baseStalePriceInterval == 0 || _quoteStalePriceInterval == 0) {
            revert Errors.NULL_STALE_PRICE();
        }

        decimals = _decimals;
        baseAggregator = _baseAggregator;
        quoteAggregator = _quoteAggregator;
        baseStalePriceInterval = _baseStalePriceInterval;
        quoteStalePriceInterval = _quoteStalePriceInterval;

        if (baseAggregator.decimals() != quoteAggregator.decimals()) {
            revert Errors.INVALID_DECIMALS(quoteAggregator.decimals());
        }

        if (address(baseAggregator) == address(quoteAggregator)) {
            if (_baseStalePriceInterval != _quoteStalePriceInterval) {
                revert Errors.INVALID_STALE_PRICE_INTERVAL(_baseStalePriceInterval, _quoteStalePriceInterval);
            }
        }
    }

    function getPrice() external view returns (uint256) {
        if (address(baseAggregator) == address(quoteAggregator)) {
            return _getPrice(baseAggregator, baseStalePriceInterval) * 10 ** decimals / 10 ** baseAggregator.decimals();
        } else {
            return Math.mulDivDown(
                _getPrice(baseAggregator, baseStalePriceInterval),
                10 ** decimals,
                _getPrice(quoteAggregator, quoteStalePriceInterval)
            );
        }
    }

    function _getPrice(AggregatorV3Interface aggregator, uint256 stalePriceInterval) internal view returns (uint256) {
        // slither-disable-next-line unused-return
        (, int256 price,, uint256 updatedAt,) = aggregator.latestRoundData();

        if (price <= 0) revert Errors.INVALID_PRICE(address(aggregator), price);
        if (block.timestamp - updatedAt > stalePriceInterval) {
            revert Errors.STALE_PRICE(address(aggregator), updatedAt);
        }

        return SafeCast.toUint256(price);
    }
}
