// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./OrderbookStorage.sol";
import "./libraries/ScheduleLibrary.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/LoanLibrary.sol";
import "./libraries/EnumerableMapExtensionsLibrary.sol";

abstract contract OrderbookView is OrderbookStorage {
    using ScheduleLibrary for Schedule;
    using UserLibrary for User;
    using LoanLibrary for Loan;
    using EnumerableMapExtensionsLibrary for EnumerableMap.UintToUintMap;

    function getBorrowerStatus(
        address _borrower
    ) public returns (BorrowerStatus memory) {
        User storage borrower = users[_borrower];
        uint256 lockedStart = borrower.cash.locked +
            (borrower.eth.locked * priceFeed.getPrice()) /
            1e18;
        return
            BorrowerStatus({
                expectedFV: borrower.schedule.expectedFV.values(),
                unlocked: borrower.schedule.unlocked.values(),
                dueFV: borrower.schedule.dueFV.values(),
                RANC: borrower.schedule.RANC(lockedStart)
            });
    }

    function getCollateralRatio(address user) public returns (uint256) {
        return users[user].collateralRatio(priceFeed.getPrice());
    }

    function isLiquidatable(address user) public returns (bool) {
        return users[user].isLiquidatable(priceFeed.getPrice(), CRLiquidation);
    }

    function getUserCollateral(
        address user
    ) public returns (uint256, uint256, uint256, uint256) {
        User storage u = users[user];
        return (u.cash.free, u.cash.locked, u.eth.free, u.eth.locked);
    }

    function activeLoans() public returns (uint256) {
        return loans.length - 1;
    }

    function loan(uint256 loanId) public returns (Loan memory loan) {
        return loans[loanId];
    }

    function isFOL(uint256 loanId) public returns (bool) {
        return loans[loanId].isFOL();
    }
}
