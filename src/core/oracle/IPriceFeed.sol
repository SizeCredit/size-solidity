// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @title IPriceFeed
interface IPriceFeed {
    /// @notice Returns the price of the asset
    function getPrice() external view returns (uint256);
    /// @notice Returns the number of decimals of the price feed
    function decimals() external view returns (uint256);
}
