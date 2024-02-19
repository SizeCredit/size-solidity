// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IMarketBorrowRateFeed} from "./IMarketBorrowRateFeed.sol";
import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

import {Math, PERCENT} from "@src/libraries/Math.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title MarketBorrowRateFeed
/// @notice A feed that returns the market borrow rate of an asset
/// @dev Aave v3 is used to get the market borrow rate
contract MarketBorrowRateFeed is IMarketBorrowRateFeed {
    using EnumerableMap for EnumerableMap.UintToUintMap;

    IPool public immutable pool;
    IERC20Metadata public immutable asset;
    uint256 public immutable stalePriceInterval;
    uint256 public immutable numberOfObservationsWeightedAverage;

    EnumerableMap.UintToUintMap internal observations;

    constructor(
        address _pool,
        address _asset,
        uint256 _stalePriceInterval,
        uint256 _numberOfObservationsWeightedAverage
    ) {
        if (_pool == address(0) || _asset == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        if (_stalePriceInterval == 0) {
            revert Errors.NULL_STALE_PRICE();
        }

        if (_numberOfObservationsWeightedAverage == 0) {
            revert Errors.NULL_NUMBER_OF_OBSERVATIONS_WEIGHTED_AVERAGE();
        }

        pool = IPool(_pool);
        asset = IERC20Metadata(_asset);
        stalePriceInterval = _stalePriceInterval;
        numberOfObservationsWeightedAverage = _numberOfObservationsWeightedAverage;
    }

    function update() external override returns (uint256 rate) {
        rate = ConversionLibrary.rayToWadDown(pool.getReserveData(address(asset)).currentVariableBorrowRate);
        observations.set(block.timestamp, rate);
    }

    function getMarketBorrowRate() external view override returns (uint256) {
        uint256 length = observations.length();
        uint256 timestampBefore = block.timestamp;
        uint256 numerator = 0;
        uint256 denominator = 0;
        for (uint256 i = length; i > length - numberOfObservationsWeightedAverage; --i) {
            (uint256 timestamp, uint256 rate) = observations.at(i - 1);

            if (timestampBefore - timestamp > stalePriceInterval) {
                revert Errors.STALE_MARKET_BORROW_RATE(timestamp);
            }
            timestampBefore = timestamp;

            numerator += rate * timestamp;
            denominator += timestamp;
        }
        return numerator / denominator;
    }
}
