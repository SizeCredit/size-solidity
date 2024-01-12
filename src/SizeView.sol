// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Config, SizeStorage} from "@src/SizeStorage.sol";

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

    function getFOLAssignedCollateral(uint256 loanId) public view returns (uint256) {
        Loan memory loan = state.loans[loanId];
        return state.getFOLAssignedCollateral(loan);
    }

    function getDebt(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getDebt();
    }

    function getCredit(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getCredit();
    }

    function config() external view returns (Config memory) {
        return state.config;
    }

    function getUserView(address user) public view returns (UserView memory) {
        return UserView({
            user: state.users[user],
            account: user,
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

    function getLoans() public view returns (Loan[] memory) {
        return state.loans;
    }

    function getLoanStatus(uint256 loanId) public view override(ISizeView) returns (LoanStatus) {
        return state.getLoanStatus(state.loans[loanId]);
    }

    function getVariablePool() public view returns (uint256, uint256, uint256) {
        return (
            state.tokens.collateralToken.balanceOf(state.config.variablePool),
            state.tokens.borrowToken.balanceOf(state.config.variablePool),
            state.tokens.debtToken.balanceOf(state.config.variablePool)
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
