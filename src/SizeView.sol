// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";
import {BorrowOffer, FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {InitializeFixedParams} from "@src/libraries/general/actions/Initialize.sol";

struct UserView {
    User user;
    address account;
    uint256 fixedCollateralAmount;
    uint256 borrowAmount;
    uint256 debtAmount;
    uint256 variableCollateralAmount;
    uint256 variableBorrowAmount;
    uint256 variableDebtAmount;
    uint256 scaledBorrowAmount;
    uint256 scaledDebtAmount;
}

abstract contract SizeView is SizeStorage {
    using OfferLibrary for FixedLoanOffer;
    using OfferLibrary for BorrowOffer;
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;

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

    function config() external view returns (InitializeFixedParams memory) {
        return InitializeFixedParams({
            collateralToken: address(state._fixed.collateralToken),
            borrowToken: address(state._fixed.borrowToken),
            debtToken: address(state._fixed.debtToken),
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
            fixedCollateralAmount: state._fixed.collateralToken.balanceOf(user),
            borrowAmount: state._fixed.borrowToken.balanceOf(user),
            debtAmount: state._fixed.debtToken.balanceOf(user),
            variableCollateralAmount: state._variable.collateralToken.balanceOf(user),
            variableBorrowAmount: state._variable.scaledBorrowToken.balanceOf(user),
            variableDebtAmount: state._variable.scaledDebtToken.balanceOf(user),
            scaledBorrowAmount: state._variable.scaledBorrowToken.scaledBalanceOf(user),
            scaledDebtAmount: state._variable.scaledDebtToken.scaledBalanceOf(user)
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

    function getFixedLoanStatus(uint256 loanId) external view returns (FixedLoanStatus) {
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
