// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@src/oracle/IMarketBorrowRateFeed.sol";

contract MarketBorrowRateFeedMock is IMarketBorrowRateFeed, Ownable {
    uint256 public marketBorrowRate;

    event MarketBorrowRateUpdated(uint256 oldMarketBorrowRate, uint256 newMarketBorrowRate);

    constructor(address owner_) Ownable(owner_) {}

    function setMarketBorrowRate(uint256 newMarketBorrowRate) public onlyOwner {
        uint256 oldMarketBorrowRate = marketBorrowRate;
        marketBorrowRate = newMarketBorrowRate;
        emit MarketBorrowRateUpdated(oldMarketBorrowRate, newMarketBorrowRate);
    }

    function getMarketBorrowRate() public view returns (uint256) {
        return marketBorrowRate;
    }
}
