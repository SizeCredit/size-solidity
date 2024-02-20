// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IMarketBorrowRateFeed} from "./IMarketBorrowRateFeed.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title MarketBorrowRateFeed
/// @notice A feed that returns the market borrow rate of an asset
/// @dev Aave v3 is used to get the market borrow rate
contract MarketBorrowRateFeed is IMarketBorrowRateFeed, Ownable2Step {
    uint256 internal marketBorrowRate;
    uint128 internal updatedAt;
    uint128 internal staleRateInterval;

    event MarketBorrowRateUpdated(uint256 oldMarketBorrowRate, uint256 newMarketBorrowRate);

    constructor(address _owner, uint128 _staleRateInterval) Ownable(_owner) {
        if (_staleRateInterval == 0) {
            revert Errors.NULL_STALE_RATE();
        }

        staleRateInterval = _staleRateInterval;
    }

    function setMarketBorrowRate(uint256 _marketBorrowRate) external onlyOwner {
        uint256 oldMarketBorrowRate = marketBorrowRate;
        marketBorrowRate = _marketBorrowRate;
        updatedAt = uint128(block.timestamp);
        emit MarketBorrowRateUpdated(oldMarketBorrowRate, _marketBorrowRate);
    }

    function getMarketBorrowRate() external view override returns (uint256) {
        if (block.timestamp - updatedAt > staleRateInterval) {
            revert Errors.STALE_RATE(updatedAt);
        }
        return marketBorrowRate;
    }
}
