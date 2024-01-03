// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User, UserView} from "@src/libraries/UserLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {ISizeView} from "@src/interfaces/ISizeView.sol";

abstract contract SizeView is SizeStorage, ISizeView {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for Loan;
    using Common for State;

    function collateralRatio(address user) public view returns (uint256) {
        return state.collateralRatio(user);
    }

    function isLiquidatable(address user) public view returns (bool) {
        return state.isLiquidatable(user);
    }

    function isLiquidatable(uint256 loanId) public view returns (bool) {
        Loan memory loan = state.loans[loanId];
        return state.isLiquidatable(loan.borrower);
    }

    function getAssignedCollateral(uint256 loanId) public view returns (uint256) {
        Loan memory loan = state.loans[loanId];
        return state.getAssignedCollateral(loan);
    }

    function getDebt(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getDebt();
    }

    function getCredit(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getCredit();
    }

    function crOpening() external view returns (uint256) {
        return state.config.crOpening;
    }

    function crLiquidation() external view returns (uint256) {
        return state.config.crLiquidation;
    }

    function collateralPercentagePremiumToLiquidator() external view returns (uint256) {
        return state.config.collateralPercentagePremiumToLiquidator;
    }

    function collateralPercentagePremiumToBorrower() external view returns (uint256) {
        return state.config.collateralPercentagePremiumToBorrower;
    }

    function collateralPercentagePremiumToProtocol() external view returns (uint256) {
        return PERCENT
            - (state.config.collateralPercentagePremiumToBorrower + state.config.collateralPercentagePremiumToLiquidator);
    }

    function getUserView(address user) public view returns (UserView memory) {
        return UserView({
            user: state.users[user],
            collateralAmount: state.tokens.collateralToken.balanceOf(user),
            borrowAmount: state.tokens.borrowToken.balanceOf(user),
            debtAmount: state.tokens.debtToken.balanceOf(user)
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

    function minimumCredit() public view returns (uint256) {
        return state.config.minimumCredit;
    }

    function getProtocolVault() public view returns (uint256, uint256, uint256) {
        return (
            state.tokens.collateralToken.balanceOf(state.vaults.protocol),
            state.tokens.borrowToken.balanceOf(state.vaults.protocol),
            state.tokens.debtToken.balanceOf(state.vaults.protocol)
        );
    }

    function getFeeRecipient() public view returns (uint256, uint256, uint256) {
        return (
            state.tokens.collateralToken.balanceOf(state.config.feeRecipient),
            state.tokens.borrowToken.balanceOf(state.config.feeRecipient),
            state.tokens.debtToken.balanceOf(state.config.feeRecipient)
        );
    }
}
