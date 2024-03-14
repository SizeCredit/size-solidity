// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@src/oracle/IMarketBorrowRateFeed.sol";

contract MarketBorrowRateFeedMock is IMarketBorrowRateFeed, Ownable {
    uint128 public marketBorrowRate;

    event MarketBorrowRateUpdated(uint128 oldMarketBorrowRate, uint128 newMarketBorrowRate);

    constructor(address owner_) Ownable(owner_) {}

    function setMarketBorrowRate(uint128 newMarketBorrowRate) public onlyOwner {
        uint128 oldMarketBorrowRate = marketBorrowRate;
        marketBorrowRate = newMarketBorrowRate;
        emit MarketBorrowRateUpdated(oldMarketBorrowRate, newMarketBorrowRate);
    }

    function getMarketBorrowRate() public view returns (uint128) {
        return marketBorrowRate;
    }
}
