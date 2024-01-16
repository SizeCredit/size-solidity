// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";

import {BorrowOffer, FixedLoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User, UserView} from "@src/libraries/UserLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";
import {InitializeExtraParams} from "@src/libraries/actions/Initialize.sol";

import {ISizeView} from "@src/interfaces/ISizeView.sol";

abstract contract SizeView is SizeStorage, ISizeView {
    using OfferLibrary for FixedLoanOffer;
    using OfferLibrary for BorrowOffer;
    using FixedLoanLibrary for FixedLoan;
    using Common for State;

    function collateralRatio(address user) external view returns (uint256) {
        return state.collateralRatio(user);
    }

    function isLiquidatable(address user) external view returns (bool) {
        return state.isLiquidatable(user);
    }

    function isLiquidatable(uint256 loanId) external view returns (bool) {
        FixedLoan memory loan = state._fixed.loans[loanId];
        return state.isLiquidatable(loan.borrower);
    }

    function getFOLAssignedCollateral(uint256 loanId) external view returns (uint256) {
        FixedLoan memory loan = state._fixed.loans[loanId];
        return state.getFOLAssignedCollateral(loan);
    }

    function getDebt(uint256 loanId) external view returns (uint256) {
        return state._fixed.loans[loanId].getDebt();
    }

    function getCredit(uint256 loanId) external view returns (uint256) {
        return state._fixed.loans[loanId].getCredit();
    }

    function config() external view returns (InitializeExtraParams memory) {
        return InitializeExtraParams({
            crOpening: state._fixed.crOpening,
            crLiquidation: state._fixed.crLiquidation,
            collateralPremiumToLiquidator: state._fixed.collateralPremiumToLiquidator,
            collateralPremiumToProtocol: state._fixed.collateralPremiumToProtocol,
            minimumCredit: state._fixed.minimumCredit
        });
    }

    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state._fixed.users[user],
            account: user,
            collateralAmount: state._fixed.collateralToken.balanceOf(user),
            borrowAmount: state._fixed.borrowToken.balanceOf(user),
            debtAmount: state._fixed.debtToken.balanceOf(user)
        });
    }

    function activeFixedLoans() external view returns (uint256) {
        return state._fixed.loans.length;
    }

    function isFOL(uint256 loanId) external view returns (bool) {
        return state._fixed.loans[loanId].isFOL();
    }

    function getFixedLoan(uint256 loanId) external view returns (FixedLoan memory) {
        return state._fixed.loans[loanId];
    }

    function getFixedLoans() external view returns (FixedLoan[] memory) {
        return state._fixed.loans;
    }

    function getFixedLoanStatus(uint256 loanId) external view override(ISizeView) returns (FixedLoanStatus) {
        return state.getFixedLoanStatus(state._fixed.loans[loanId]);
    }

    function getVariablePool() external view returns (uint256, uint256, uint256) {
        return (
            state._fixed.collateralToken.balanceOf(state._general.variablePool),
            state._fixed.borrowToken.balanceOf(state._general.variablePool),
            state._fixed.debtToken.balanceOf(state._general.variablePool)
        );
    }

    function getFeeRecipient() external view returns (uint256, uint256, uint256) {
        return (
            state._fixed.collateralToken.balanceOf(state._general.feeRecipient),
            state._fixed.borrowToken.balanceOf(state._general.feeRecipient),
            state._fixed.debtToken.balanceOf(state._general.feeRecipient)
        );
    }
}
