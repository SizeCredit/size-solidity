// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@src/oracle/IVariablePoolBorrowRateFeed.sol";

contract VariablePoolBorrowRateFeedMock is IVariablePoolBorrowRateFeed, Ownable {
    uint128 public borrowRate;

    event BorrowRateUpdated(uint128 oldBorrowRate, uint128 newBorrowRate);

    constructor(address owner_) Ownable(owner_) {}

    function setVariableBorrowRate(uint128 newBorrowRate) public onlyOwner {
        uint128 oldBorrowRate = borrowRate;
        borrowRate = newBorrowRate;
        emit BorrowRateUpdated(oldBorrowRate, newBorrowRate);
    }

    function getVariableBorrowRate() public view returns (uint128) {
        return borrowRate;
    }
}
