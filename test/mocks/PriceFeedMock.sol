// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../../src/oracle/IPriceFeed.sol";

contract PriceFeedMock is IPriceFeed, Ownable {
    uint256 public price;

    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    constructor(address owner) Ownable(owner) {}

    function setPrice(uint256 newPrice) public onlyOwner {
        uint256 oldPrice = price;
        price = newPrice;
        emit PriceUpdated(oldPrice, newPrice);
    }

    function getPrice() public view returns (uint256) {
        return price;
    }
}
