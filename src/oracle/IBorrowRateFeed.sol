// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @title IBorrowRateFeed
interface IBorrowRateFeed {
    /// @notice Returns the borrow rate with 18 decimals
    /// @dev Ex, returns 0.05e18 for 5%
    function getBorrowRate() external view returns (uint128);
}
