// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IMarketBorrowRateFeed} from "./IMarketBorrowRateFeed.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title MarketBorrowRateFeed
/// @notice A feed that returns the market borrow rate of an asset with 18 decimals
/// @dev Aave v3 is used to get the market borrow rate
contract MarketBorrowRateFeed is IMarketBorrowRateFeed, Ownable2Step {
    uint128 internal marketBorrowRate;
    uint64 internal marketBorrowRateUpdatedAt;
    uint64 internal staleRateInterval;

    event MarketBorrowRateUpdated(uint128 oldMarketBorrowRate, uint128 newMarketBorrowRate);
    event StaleRateIntervalUpdated(uint64 oldStaleRateInterval, uint64 newStaleRateInterval);

    constructor(address _owner, uint64 _staleRateInterval) Ownable(_owner) {
        if (_staleRateInterval == 0) {
            revert Errors.NULL_STALE_RATE();
        }

        staleRateInterval = _staleRateInterval;
    }

    function setStaleRateInterval(uint64 _staleRateInterval) external onlyOwner {
        uint64 oldStaleRateInterval = staleRateInterval;
        staleRateInterval = _staleRateInterval;
        emit StaleRateIntervalUpdated(oldStaleRateInterval, _staleRateInterval);
    }

    function setMarketBorrowRate(uint128 _marketBorrowRate) external onlyOwner {
        uint128 oldMarketBorrowRate = marketBorrowRate;
        marketBorrowRate = _marketBorrowRate;
        marketBorrowRateUpdatedAt = uint64(block.timestamp);
        emit MarketBorrowRateUpdated(oldMarketBorrowRate, _marketBorrowRate);
    }

    function getMarketBorrowRate() external view override returns (uint128) {
        if (block.timestamp - marketBorrowRateUpdatedAt > staleRateInterval) {
            revert Errors.STALE_RATE(marketBorrowRateUpdatedAt);
        }
        return marketBorrowRate;
    }
}
