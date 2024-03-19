// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IBorrowRateFeed} from "./IBorrowRateFeed.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Roles} from "@src/libraries/Roles.sol";

/// @title BorrowRateFeed
/// @notice A feed that returns the borrow rate of an asset with 18 decimals
/// @dev Aave v3 is used to get the market borrow rate, and the Variable Pool is used as a fallback rate
///      For the fallback rate computation, we perform the following "Median of Medians" algorithm:
///          1. Keep a list of the last N timestamp.
///          2. For each timestamp, we track up to M liquidity indexes resulting from such events.
///          3. Each timestamp will have an associated rate consisting of the median of the m <= M points in that timestamp.
///          4. Finally, we compute the median of the last N timestamp' medians.
contract BorrowRateFeed is IBorrowRateFeed, AccessControl {
    uint128 internal marketBorrowRate;
    uint64 internal marketBorrowRateUpdatedAt;
    uint64 internal staleRateInterval;

    uint128 internal variablePoolBorrowRate;
    uint64 internal variablePoolBorrowRateUpdatedAt;
    uint256 internal variablePoolBorrowRatePointsPerTimestampLimit;
    uint256 internal variablePoolBorrowRateTimestampsLimit;
    mapping(uint256 timestamp => uint256[] observationsPerTimestamp) internal observations;
    mapping(uint256 timestamp => uint256 variablePoolBorrowRate) internal medianObservations;
    uint256[] internal timestamps;

    event MarketBorrowRateUpdated(uint128 indexed oldMarketBorrowRate, uint128 indexed newMarketBorrowRate);
    event VariablePoolBorrowRateUpdated(
        uint128 indexed oldVariablePoolBorrowRate, uint128 indexed newVariablePoolBorrowRate
    );
    event StaleRateIntervalUpdated(uint64 indexed oldStaleRateInterval, uint64 indexed newStaleRateInterval);

    constructor(address _owner, address _size, uint64 _staleRateInterval) {
        if (_owner == address(0) || _size == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        if (_staleRateInterval == 0) {
            revert Errors.NULL_STALE_RATE();
        }

        staleRateInterval = _staleRateInterval;
        emit StaleRateIntervalUpdated(0, _staleRateInterval);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(Roles.KEEPER_ROLE, _owner);
        _grantRole(Roles.SIZE_ROLE, _size);
    }

    function updateVariablePoolBorrowRate(uint128 _variablePoolBorrowRate) external onlyRole(Roles.SIZE_ROLE) {
        uint256[] storage observationsPerTimestamp = observations[block.timestamp];
        if (observationsPerTimestamp.length == 0) {
            timestamps.push(block.timestamp);
        }
        observationsPerTimestamp[block.timestamp].push(_variablePoolBorrowRate);

        if (observationsPerTimestamp.length > 1) {
            // caldulate median
            uint256 median = 1337;
            medianObservations[block.timestamp] = median;
        }

        uint256 medianOfMedians;
        for (uint256 i = timestamps.length; i > timestamps.length - variablePoolBorrowRateTimestampsLimit; i--) {
            uint256 timestamp = timestamps[i - 1];
            uint256 variablePoolBorrowRatePerTimestamp = medianObservations[timestamp];

            // calculate median of medians
            medianOfMedians = 1337;
        }

        uint128 oldVariablePoolBorrowRate = variablePoolBorrowRate;
        variablePoolBorrowRate = medianOfMedians;
        variablePoolBorrowRateUpdatedAt = uint64(block.timestamp);
        emit VariablePoolBorrowRateUpdated(oldVariablePoolBorrowRate, medianOfMedians);
    }

    function setStaleRateInterval(uint64 _staleRateInterval) external onlyRole(Roles.KEEPER_ROLE) {
        uint64 oldStaleRateInterval = staleRateInterval;
        staleRateInterval = _staleRateInterval;
        emit StaleRateIntervalUpdated(oldStaleRateInterval, _staleRateInterval);
    }

    function setMarketBorrowRate(uint128 _marketBorrowRate) external onlyRole(Roles.KEEPER_ROLE) {
        uint128 oldMarketBorrowRate = marketBorrowRate;
        marketBorrowRate = _marketBorrowRate;
        marketBorrowRateUpdatedAt = uint64(block.timestamp);
        emit MarketBorrowRateUpdated(oldMarketBorrowRate, _marketBorrowRate);
    }

    function getMarketBorrowRate() external view override returns (uint128) {
        if (block.timestamp - marketBorrowRateUpdatedAt > staleRateInterval) {
            return variablePoolBorrowRate;
        } else {
            return marketBorrowRate;
        }
    }
}
