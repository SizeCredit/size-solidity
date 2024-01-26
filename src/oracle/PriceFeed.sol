// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Math} from "@src/libraries/Math.sol";

import {IPriceFeed} from "./IPriceFeed.sol";
import {Errors} from "@src/libraries/Errors.sol";

/**
 * _base: ETH/USD feed
 * _quote: USDC/USD feed
 * _decimals: 18
 * _baseStalePrice: 3600 seconds (https://data.chain.link/ethereum/mainnet/crypto-usd/eth-usd)
 * _quoteStalePrice: 86400 seconds (https://data.chain.link/ethereum/mainnet/stablecoins/usdc-usd)
 *
 * answer: ETH/USDC in 1e18
 */
contract PriceFeed is IPriceFeed {
    /* solhint-disable immutable-vars-naming */
    AggregatorV3Interface public immutable base;
    AggregatorV3Interface public immutable quote;
    uint8 public immutable decimals;
    uint8 public immutable baseDecimals;
    uint8 public immutable quoteDecimals;
    uint256 public immutable baseStalePrice;
    uint256 public immutable quoteStalePrice;

    /* solhint-enable immutable-vars-naming */

    constructor(address _base, address _quote, uint8 _decimals, uint256 _baseStalePrice, uint256 _quoteStalePrice) {
        if (_base == address(0) || _quote == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        if (_decimals == 0 || _decimals > 18) {
            revert Errors.INVALID_DECIMALS(_decimals);
        }

        if (_baseStalePrice == 0 || _quoteStalePrice == 0) {
            revert Errors.NULL_STALE_PRICE();
        }

        base = AggregatorV3Interface(_base);
        quote = AggregatorV3Interface(_quote);
        decimals = _decimals;
        baseStalePrice = _baseStalePrice;
        quoteStalePrice = _quoteStalePrice;

        baseDecimals = base.decimals();
        quoteDecimals = quote.decimals();
    }

    function getPrice() external view returns (uint256) {
        return Math.mulDivDown(_getPrice(base, baseStalePrice), 10 ** decimals, _getPrice(quote, quoteStalePrice));
    }

    function _getPrice(AggregatorV3Interface aggregator, uint256 stalePrice) internal view returns (uint256) {
        // slither-disable-next-line unused-return
        (, int256 price,, uint256 updatedAt,) = aggregator.latestRoundData();

        if (price <= 0) revert Errors.INVALID_PRICE(address(aggregator), price);
        if (block.timestamp - updatedAt > stalePrice) {
            revert Errors.STALE_PRICE(address(aggregator), updatedAt);
        }

        price = _scalePrice(price, aggregator.decimals(), decimals);

        return uint256(price);
    }

    function _scalePrice(int256 _price, uint8 _priceDecimals, uint8 _decimals) internal pure returns (int256) {
        if (_priceDecimals < _decimals) {
            return _price * int256(10 ** uint256(_decimals - _priceDecimals));
        } else if (_priceDecimals > _decimals) {
            return _price / int256(10 ** uint256(_priceDecimals - _decimals));
        } else {
            return _price;
        }
    }
}
