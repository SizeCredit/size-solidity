// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@src/libraries/Math.sol";

import {IPriceFeed} from "./IPriceFeed.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title PriceFeed
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice A contract that provides the price of a `base` asset in terms of a `quote` asset, using an intermediate asset, scaled to 18 decimals (1)
///         If `base` and `quote` are equal, the aggregator provided is the price of the asset without any intermediate asset (2)
/// @dev The price is calculated as `base / quote`
///      Example configuration (1)
///         _base: ETH/USD feed
///         _quote: USDC/USD feed
///         _sequencerUptimeFeed: the sequencer uptime feed for supported L2s (https://docs.chain.link/data-feeds/l2-sequencer-feeds)
///         _baseStalePriceInterval: 3600 seconds (https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd)
///         _quoteStalePriceInterval: 86400 seconds (https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd)
///         answer: ETH/USDC in 1e18
///         Note: _base and _quote must have the same number of decimals
///         Note: _base and _quote must have the same intermediate asset (in this example, USD)
///      Example configuration (2)
///         _base: STETH/ETH feed
///         _quote: STETH/ETH feed
///         _sequencerUptimeFeed: the sequencer uptime feed for supported L2s (https://docs.chain.link/data-feeds/l2-sequencer-feeds)
///         _baseStalePriceInterval: 86400 seconds (https://data.chain.link/feeds/base/base/steth-eth)
///         _quoteStalePriceInterval: 86400 seconds (https://data.chain.link/feeds/base/base/steth-eth)
///         answer: STETH/ETH in 1e18
contract PriceFeed is IPriceFeed {
    uint256 private constant GRACE_PERIOD_TIME = 3600;

    /* solhint-disable */
    uint256 public constant decimals = 18;
    AggregatorV3Interface public immutable base;
    AggregatorV3Interface public immutable quote;
    AggregatorV3Interface internal immutable sequencerUptimeFeed;
    uint256 public immutable baseStalePriceInterval;
    uint256 public immutable quoteStalePriceInterval;
    /* solhint-enable */

    constructor(
        address _base,
        address _quote,
        address _sequencerUptimeFeed,
        uint256 _baseStalePriceInterval,
        uint256 _quoteStalePriceInterval
    ) {
        if (_base == address(0) || _quote == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        // the _sequencerUptimeFeed can be null for unsupported networks

        if (_baseStalePriceInterval == 0 || _quoteStalePriceInterval == 0) {
            revert Errors.NULL_STALE_PRICE();
        }

        base = AggregatorV3Interface(_base);
        quote = AggregatorV3Interface(_quote);
        sequencerUptimeFeed = AggregatorV3Interface(_sequencerUptimeFeed);
        baseStalePriceInterval = _baseStalePriceInterval;
        quoteStalePriceInterval = _quoteStalePriceInterval;

        if (base.decimals() != quote.decimals()) {
            revert Errors.INVALID_DECIMALS(quote.decimals());
        }

        if (address(base) == address(quote)) {
            if (_baseStalePriceInterval != _quoteStalePriceInterval) {
                revert Errors.INVALID_STALE_PRICE_INTERVAL(_baseStalePriceInterval, _quoteStalePriceInterval);
            }
        }
    }

    function getPrice() external view returns (uint256) {
        if (address(sequencerUptimeFeed) != address(0)) {
            // slither-disable-next-line unused-return
            (, int256 answer, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();

            if (startedAt == 0 || answer == 1) {
                // sequencer is down
                revert Errors.SEQUENCER_DOWN();
            }

            if (block.timestamp - startedAt <= GRACE_PERIOD_TIME) {
                // time since up
                revert Errors.GRACE_PERIOD_NOT_OVER();
            }
        }

        if (address(base) == address(quote)) {
            return _getPrice(base, baseStalePriceInterval) * 10 ** decimals / 10 ** base.decimals();
        } else {
            return Math.mulDivDown(
                _getPrice(base, baseStalePriceInterval), 10 ** decimals, _getPrice(quote, quoteStalePriceInterval)
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
