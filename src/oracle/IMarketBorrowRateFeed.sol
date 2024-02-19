// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @title IMarketBorrowRateFeed
interface IMarketBorrowRateFeed {
    /// @notice Update the market borrow rate and returns the most recent rate
    /// @dev This function updates the most recent rate whenever it is called.
    ///      It is possible to manipulate the most recent rate by performing actions on the market before/after this function is called.
    function update() external returns (uint256);
    /// @notice Returns the market borrow rate in 18 decimals
    function getMarketBorrowRate() external view returns (uint256);
}
