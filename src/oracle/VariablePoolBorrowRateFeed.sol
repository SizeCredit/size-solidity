// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IVariablePoolBorrowRateFeed} from "./IVariablePoolBorrowRateFeed.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Errors} from "@src/libraries/Errors.sol";

/// @title VariablePoolBorrowRateFeed
/// @notice A feed that returns the market borrow rate of an asset with 18 decimals
/// @dev Aave v3 is used to get the market borrow rate
contract VariablePoolBorrowRateFeed is IVariablePoolBorrowRateFeed, Ownable2Step {
    uint128 internal borrowRate;
    uint64 internal borrowRateUpdatedAt;
    uint64 internal staleRateInterval;

    event BorrowRateUpdated(uint128 indexed oldBorrowRate, uint128 indexed newBorrowRate);
    event StaleRateIntervalUpdated(uint64 indexed oldStaleRateInterval, uint64 indexed newStaleRateInterval);

    constructor(address _owner, uint64 _staleRateInterval, uint128 _borrowRate) Ownable(_owner) {
        if (_staleRateInterval == 0) {
            revert Errors.NULL_STALE_RATE();
        }

        _setStaleRateInterval(_staleRateInterval);
        _setVariableBorrowRate(_borrowRate);
    }

    function setStaleRateInterval(uint64 _staleRateInterval) external onlyOwner {
        _setStaleRateInterval(_staleRateInterval);
    }

    function _setStaleRateInterval(uint64 _staleRateInterval) internal {
        uint64 oldStaleRateInterval = staleRateInterval;
        staleRateInterval = _staleRateInterval;
        emit StaleRateIntervalUpdated(oldStaleRateInterval, _staleRateInterval);
    }

    function setVariableBorrowRate(uint128 _borrowRate) external onlyOwner {
        _setVariableBorrowRate(_borrowRate);
    }

    function _setVariableBorrowRate(uint128 _borrowRate) internal {
        uint128 oldBorrowRate = borrowRate;
        borrowRate = _borrowRate;
        borrowRateUpdatedAt = uint64(block.timestamp);
        emit BorrowRateUpdated(oldBorrowRate, _borrowRate);
    }

    function getVariableBorrowRate() external view override returns (uint128) {
        if (block.timestamp - borrowRateUpdatedAt > staleRateInterval) {
            revert Errors.STALE_RATE(borrowRateUpdatedAt);
        }
        return borrowRate;
    }
}
