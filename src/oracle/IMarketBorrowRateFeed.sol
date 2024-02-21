// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @title IMarketBorrowRateFeed
interface IMarketBorrowRateFeed {
    /// @notice Returns the market borrow rate with 18 decimals
    /// @dev Ex, returns 0.05e18 for 5%
    function getMarketBorrowRate() external view returns (uint128);
}
