// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @title IMarketBorrowRateFeed
interface IMarketBorrowRateFeed {
    /// @notice Returns the market borrow rate
    function getMarketBorrowRate() external view returns (uint128);
}
