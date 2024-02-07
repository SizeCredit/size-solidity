// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IMarketBorrowRateFeed {
    function getMarketBorrowRate() external view returns (uint256);
}
