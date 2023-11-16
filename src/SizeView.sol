// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/LoanLibrary.sol";
import "./libraries/OfferLibrary.sol";
import "./libraries/EnumerableMapExtensionsLibrary.sol";

abstract contract SizeView is SizeStorage {
    using UserLibrary for User;
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;
    using EnumerableMapExtensionsLibrary for EnumerableMap.UintToUintMap;

    function getCollateralRatio(address user) public returns (uint256) {
        return users[user].collateralRatio(priceFeed.getPrice());
    }

    function isLiquidatable(address user) public returns (bool) {
        return users[user].isLiquidatable(priceFeed.getPrice(), CRLiquidation);
    }

    function getUserCollateral(address user) public view returns (uint256, uint256, uint256, uint256) {
        User storage u = users[user];
        return (u.cash.free, u.cash.locked, u.eth.free, u.eth.locked);
    }

    function activeLoans() public view returns (uint256) {
        return loans.length - 1;
    }

    function loan(uint256 loanId) public view returns (Loan memory) {
        return loans[loanId];
    }

    function isFOL(uint256 loanId) public view returns (bool) {
        return loans[loanId].isFOL();
    }

    function getRate(uint256 offerId, uint256 dueDate) public view returns (uint256) {
        return loanOffers[offerId].getRate(dueDate);
    }

    function getDueDate(uint256 loanId) public view returns (uint256) {
        return loans[loanId].getDueDate(loans);
    }
}
