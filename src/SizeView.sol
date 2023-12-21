// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User, UserView} from "@src/libraries/UserLibrary.sol";
import {LiquidateLoan} from "@src/libraries/actions/LiquidateLoan.sol";
import {Common} from "@src/libraries/actions/Common.sol";
import {State} from "@src/SizeStorage.sol";

import {ISizeView} from "@src/interfaces/ISizeView.sol";

abstract contract SizeView is SizeStorage, ISizeView {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for Loan;
    using Common for State;

    function collateralRatio(address user) public view returns (uint256) {
        return LiquidateLoan.collateralRatio(state, user);
    }

    function isLiquidatable(address user) public view returns (bool) {
        return LiquidateLoan.isLiquidatable(state, user);
    }

    function isLiquidatable(uint256 loanId) public view returns (bool) {
        Loan memory loan = state.loans[loanId];
        return LiquidateLoan.isLiquidatable(state, loan.borrower);
    }

    function getAssignedCollateral(uint256 loanId) public view returns (uint256) {
        Loan memory loan = state.loans[loanId];
        return LiquidateLoan.getAssignedCollateral(state, loan);
    }

    function getDebt(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getDebt();
    }

    function crOpening() external view returns (uint256) {
        return state.crOpening;
    }

    function crLiquidation() external view returns (uint256) {
        return state.crLiquidation;
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

    function getUserView(address user) public view returns (UserView memory) {
        return UserView({
            user: state.users[user],
            collateralAmount: state.collateralToken.balanceOf(user),
            borrowAmount: state.borrowToken.balanceOf(user),
            debtAmount: state.debtToken.balanceOf(user)
        });
    }

    function activeLoans() public view returns (uint256) {
        return state.loans.length;
    }

    function activeVariableLoans() public view returns (uint256) {
        return state.variableLoans.length;
    }

    function isFOL(uint256 loanId) public view returns (bool) {
        return state.loans[loanId].isFOL();
    }

    function getLoan(uint256 loanId) public view returns (Loan memory) {
        return state.loans[loanId];
    }

    function getLoanStatus(uint256 loanId) public view override(ISizeView) returns (LoanStatus) {
        return state.getLoanStatus(state.loans[loanId]);
    }

    function getLoanOffer(address account) public view returns (LoanOffer memory) {
        return state.users[account].loanOffer;
    }

    function getBorrowOffer(address account) public view returns (BorrowOffer memory) {
        return state.users[account].borrowOffer;
    }

    function getDueDate(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].dueDate;
    }
}
