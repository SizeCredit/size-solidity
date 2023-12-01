// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage, State} from "@src/SizeStorage.sol";
import {User, UserLibrary} from "@src/libraries/UserLibrary.sol";
import {Loan, LoanStatus, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

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
        return borrower.getAssignedCollateral(loan.FV);
    }

    function getDebt(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getDebt();
    }

    function CROpening() external view returns (uint256) {
        return state.CROpening;
    }

    function CRLiquidation() external view returns (uint256) {
        return state.CRLiquidation;
    }

    function collateralPercentagePremiumToLiquidator() external view returns (uint256) {
        return state.collateralPercentagePremiumToLiquidator;
    }

    function collateralPercentagePremiumToBorrower() external view returns (uint256) {
        return state.collateralPercentagePremiumToBorrower;
    }

    function collateralPercentagePremiumToProtocol() external view returns (uint256) {
        return PERCENT - (state.collateralPercentagePremiumToBorrower + state.collateralPercentagePremiumToLiquidator);
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

    function getLoan(uint256 loanId) public view returns (Loan memory) {
        return state.loans[loanId];
    }

    function getLoanStatus(uint256 loanId) public view returns (LoanStatus) {
        return state.loans[loanId].getLoanStatus(state.loans);
    }

    function getLoanOffer(address account) public view returns (LoanOffer memory) {
        return state.users[account].loanOffer;
    }
}
