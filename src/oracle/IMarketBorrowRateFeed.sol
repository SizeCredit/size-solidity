// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IMarketBorrowRateFeed {
    function getMarketBorrowRate() external view returns (uint256);
}
