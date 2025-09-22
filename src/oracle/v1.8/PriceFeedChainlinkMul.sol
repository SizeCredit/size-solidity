// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Errors} from "@src/market/libraries/Errors.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {IPriceFeed} from "@src/oracle/IPriceFeed.sol";

/// @title PriceFeedChainlinkMul
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice If `baseAggregator` and `quoteAggregator` are equal, the result is the price of the aggregator without any intermediate asset
/// @dev The price is calculated as `base * quote`
///      Example configuration
///         _base: WBTC/BTC feed
///         _quote: BTC/USD feed
///         _baseStalePriceInterval: 86400 seconds (https://data.chain.link/ethereum/mainnet/crypto-usd/wbtc-btc)
///         _quoteStalePriceInterval: 3600 seconds (https://data.chain.link/ethereum/mainnet/crypto-usd/btc-usd)
///         answer: WBTC/USD in 1e18
contract PriceFeedChainlinkMul is IPriceFeed {
    /* solhint-disable */
    uint256 public immutable decimals = 18;
    AggregatorV3Interface public immutable baseAggregator;
    AggregatorV3Interface public immutable quoteAggregator;
    uint256 public immutable baseStalePriceInterval;
    uint256 public immutable quoteStalePriceInterval;
    int256 public immutable decimalsDelta;
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

        if (address(baseAggregator) == address(quoteAggregator)) {
            if (_baseStalePriceInterval != _quoteStalePriceInterval) {
                revert Errors.INVALID_STALE_PRICE_INTERVAL(_baseStalePriceInterval, _quoteStalePriceInterval);
            }
        }
        decimalsDelta = SafeCast.toInt256(_decimals) - SafeCast.toInt256(_quoteAggregator.decimals())
            - SafeCast.toInt256(_baseAggregator.decimals());
    }

    function getPrice() external view returns (uint256) {
        if (address(baseAggregator) == address(quoteAggregator)) {
            return _getPrice(baseAggregator, baseStalePriceInterval) * 10 ** decimals / 10 ** baseAggregator.decimals();
        } else {
            if (decimalsDelta >= 0) {
                return _getPrice(baseAggregator, baseStalePriceInterval)
                    * _getPrice(quoteAggregator, quoteStalePriceInterval) * 10 ** uint256(decimalsDelta);
            } else {
                return Math.mulDivDown(
                    _getPrice(baseAggregator, baseStalePriceInterval),
                    _getPrice(quoteAggregator, quoteStalePriceInterval),
                    10 ** uint256(-decimalsDelta)
                );
            }
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
