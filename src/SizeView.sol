// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/LoanLibrary.sol";
import "./libraries/OfferLibrary.sol";

abstract contract SizeView is SizeStorage {
    using UserLibrary for User;
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;

    function getCollateralRatio(address user) public view returns (uint256) {
        return users[user].collateralRatio(priceFeed.getPrice());
    }

    function isLiquidatable(address user) public view returns (bool) {
        return users[user].isLiquidatable(priceFeed.getPrice(), CRLiquidation);
    }

    function isLiquidatable(uint256 loanId) public view returns (bool) {
        Loan memory loan = loans[loanId];
        return users[loan.borrower].isLiquidatable(priceFeed.getPrice(), CRLiquidation);
    }

    function getAssignedCollateral(uint256 loanId) public view returns (uint256) {
        Loan memory loan = loans[loanId];
        User memory borrower = users[loan.borrower];
        if (borrower.totDebtCoveredByRealCollateral == 0) {
            return 0;
        } else {
            return borrower.eth.free * loan.FV / borrower.totDebtCoveredByRealCollateral;
        }
    }

    function getUser(address user) public view returns (User memory) {
        return users[user];
    }

    function activeLoans() public view returns (uint256) {
        return loans.length - 1;
    }

    function activeLoanOffers() public view returns (uint256) {
        return loanOffers.length - 1;
    }

    function activeBorrowOffers() public view returns (uint256) {
        return borrowOffers.length - 1;
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

    function getLoan(uint256 loanId) public view returns (Loan memory) {
        return loans[loanId];
    }

    function getLoanOffer(uint256 loanOfferId) public view returns (LoanOffer memory) {
        return loanOffers[loanOfferId];
    }
}
