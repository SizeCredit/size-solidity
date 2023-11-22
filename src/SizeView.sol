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

    function isFOL(uint256 loanId) public view returns (bool) {
        return loans[loanId].isFOL();
    }

    function getRate(address account, uint256 dueDate) public view returns (uint256) {
        return loanOffers[account].getRate(dueDate);
    }

    function getDueDate(uint256 loanId) public view returns (uint256) {
        return loans[loanId].getDueDate(loans);
    }

    function getLoan(uint256 loanId) public view returns (Loan memory) {
        return loans[loanId];
    }

    function getLoanOffer(address account) public view returns (LoanOffer memory) {
        return loanOffers[account];
    }

    function getUserVirtualCollateralPerDate(address account, uint256 dueDate) public view returns (uint256 res) {
        for (uint256 i; i < loans.length; ++i) {
            Loan memory loan = loans[i];
            if (loan.lender == account && !loan.repaid && loan.getDueDate(loans) <= dueDate) {
                res += loan.getCredit();
            }
        }
    }

    function getUserVirtualCollateralInRange(address account, uint256[] memory dueDates)
        public
        view
        returns (uint256[] memory res)
    {
        res = new uint256[](dueDates.length);
        for (uint256 i; i < dueDates.length; ++i) {
            res[i] = getUserVirtualCollateralPerDate(account, dueDates[i]);
        }
    }

    function getFreeVirtualCollateral(address account, uint256 dueDate) public view returns (uint256 res) {
        for (uint256 i; i < loans.length; ++i) {
            Loan memory loan = loans[i];
            if (loan.lender == account && loan.getDueDate(loans) <= dueDate) {
                res += loan.getCredit();
            }
        }
    }
}
