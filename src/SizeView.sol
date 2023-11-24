// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage, State} from "@src/SizeStorage.sol";
import {User, UserLibrary} from "@src/libraries/UserLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

abstract contract SizeView is SizeStorage {
    using UserLibrary for User;
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for Loan;

    function getCollateralRatio(address user) public view returns (uint256) {
        return state.users[user].collateralRatio(state.priceFeed.getPrice());
    }

    function isLiquidatable(address user) public view returns (bool) {
        return state.users[user].isLiquidatable(state.priceFeed.getPrice(), state.CRLiquidation);
    }

    function isLiquidatable(uint256 loanId) public view returns (bool) {
        Loan memory loan = state.loans[loanId];
        return state.users[loan.borrower].isLiquidatable(state.priceFeed.getPrice(), state.CRLiquidation);
    }

    function getAssignedCollateral(uint256 loanId) public view returns (uint256) {
        Loan memory loan = state.loans[loanId];
        User memory borrower = state.users[loan.borrower];
        if (borrower.totDebtCoveredByRealCollateral == 0) {
            return 0;
        } else {
            return borrower.eth.free * loan.FV / borrower.totDebtCoveredByRealCollateral;
        }
    }

    function CROpening() external view returns (uint256) {
        return state.CROpening;
    }

    function CRLiquidation() external view returns (uint256) {
        return state.CRLiquidation;
    }

    function getUser(address user) public view returns (User memory) {
        return state.users[user];
    }

    function activeLoans() public view returns (uint256) {
        return state.loans.length - 1;
    }

    function isFOL(uint256 loanId) public view returns (bool) {
        return state.loans[loanId].isFOL();
    }

    function getLoanOfferRate(address account, uint256 dueDate) public view returns (uint256) {
        return state.users[account].loanOffer.getRate(dueDate);
    }

    function getDueDate(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getDueDate(state.loans);
    }

    function getLoan(uint256 loanId) public view returns (Loan memory) {
        return state.loans[loanId];
    }

    function getLoanOffer(address account) public view returns (LoanOffer memory) {
        return state.users[account].loanOffer;
    }

    function getBorrowOffer(address account) public view returns (BorrowOffer memory) {
        return state.users[account].borrowOffer;
    }

    function getUserVirtualCollateralPerDate(address account, uint256 dueDate) public view returns (uint256 res) {
        for (uint256 i; i < state.loans.length; ++i) {
            Loan memory loan = state.loans[i];
            if (loan.lender == account && !loan.repaid && loan.getDueDate(state.loans) <= dueDate) {
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
        for (uint256 i; i < state.loans.length; ++i) {
            Loan memory loan = state.loans[i];
            if (loan.lender == account && loan.getDueDate(state.loans) <= dueDate) {
                res += loan.getCredit();
            }
        }
    }
}
