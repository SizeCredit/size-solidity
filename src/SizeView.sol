// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Fixed, General, SizeStorage, State} from "@src/SizeStorage.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {BorrowOffer, FixedLoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User, UserView} from "@src/libraries/UserLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {ISizeView} from "@src/interfaces/ISizeView.sol";

abstract contract SizeView is SizeStorage, ISizeView {
    using OfferLibrary for FixedLoanOffer;
    using OfferLibrary for BorrowOffer;
    using FixedLoanLibrary for FixedLoan;
    using Common for State;

    function collateralRatio(address user) public view returns (uint256) {
        return state.collateralRatio(user);
    }

    function isLiquidatable(address user) public view returns (bool) {
        return state.isLiquidatable(user);
    }

    function isLiquidatable(uint256 loanId) public view returns (bool) {
        FixedLoan memory loan = state.loans[loanId];
        return state.isLiquidatable(loan.borrower);
    }

    function getFOLAssignedCollateral(uint256 loanId) public view returns (uint256) {
        FixedLoan memory loan = state.loans[loanId];
        return state.getFOLAssignedCollateral(loan);
    }

    function getDebt(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getDebt();
    }

    function getCredit(uint256 loanId) public view returns (uint256) {
        return state.loans[loanId].getCredit();
    }

    function g() external view returns (General memory) {
        return state.g;
    }

    function f() external view returns (Fixed memory) {
        return state.f;
    }

    function getUserView(address user) public view returns (UserView memory) {
        return UserView({
            user: state.users[user],
            account: user,
            collateralAmount: state.f.collateralToken.balanceOf(user),
            borrowAmount: state.f.borrowToken.balanceOf(user),
            debtAmount: state.f.debtToken.balanceOf(user)
        });
    }

    function activeFixedLoans() public view returns (uint256) {
        return state.loans.length;
    }

    function isFOL(uint256 loanId) public view returns (bool) {
        return state.loans[loanId].isFOL();
    }

    function getFixedLoan(uint256 loanId) public view returns (FixedLoan memory) {
        return state.loans[loanId];
    }

    function getFixedLoans() public view returns (FixedLoan[] memory) {
        return state.loans;
    }

    function getFixedLoanStatus(uint256 loanId) public view override(ISizeView) returns (FixedLoanStatus) {
        return state.getFixedLoanStatus(state.loans[loanId]);
    }

    function getVariablePool() public view returns (uint256, uint256, uint256) {
        return (
            state.f.collateralToken.balanceOf(state.g.variablePool),
            state.f.borrowToken.balanceOf(state.g.variablePool),
            state.f.debtToken.balanceOf(state.g.variablePool)
        );
    }

    function getFeeRecipient() public view returns (uint256, uint256, uint256) {
        return (
            state.f.collateralToken.balanceOf(state.g.feeRecipient),
            state.f.borrowToken.balanceOf(state.g.feeRecipient),
            state.f.debtToken.balanceOf(state.g.feeRecipient)
        );
    }
}
