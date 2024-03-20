// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @title IVariablePoolBorrowRateFeed
interface IVariablePoolBorrowRateFeed {
    /// @notice Returns the market borrow rate with 18 decimals
    /// @dev Ex, returns 0.05e18 for 5%
    function getVariableBorrowRate() external view returns (uint128);
}
