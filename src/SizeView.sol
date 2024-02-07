// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {
    InitializeConfigParams,
    InitializeDataParams,
    InitializeOracleParams
} from "@src/libraries/general/actions/Initialize.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

struct UserView {
    User user;
    address account;
    uint256 collateralAmount;
    uint256 borrowAmount;
    uint256 debtAmount;
}

abstract contract SizeView is SizeStorage {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;

    function collateralRatio(address user) external view returns (uint256) {
        return state.collateralRatio(user);
    }

    function isUserLiquidatable(address user) external view returns (bool) {
        return state.isUserLiquidatable(user);
    }

    function isLoanLiquidatable(uint256 loanId) external view returns (bool) {
        return state.isLoanLiquidatable(loanId);
    }

    function getFOLAssignedCollateral(uint256 loanId) external view returns (uint256) {
        Loan memory loan = state.data.loans[loanId];
        return state.getFOLAssignedCollateral(loan);
    }

    function getDebt(uint256 loanId) external view returns (uint256) {
        Loan storage loan = state.data.loans[loanId];
        Loan storage fol = state.getFOL(loan);
        return state.getDebt(fol);
    }

    function faceValue(uint256 loanId) external view returns (uint256) {
        Loan storage loan = state.data.loans[loanId];
        Loan storage fol = state.getFOL(loan);
        return fol.faceValue();
    }

    function getCredit(uint256 loanId) external view returns (uint256) {
        return state.data.loans[loanId].generic.credit;
    }

    function getDueDate(uint256 loanId) external view returns (uint256) {
        Loan storage loan = state.data.loans[loanId];
        return state.getFOL(loan).fol.dueDate;
    }

    function config() external view returns (InitializeConfigParams memory) {
        return InitializeConfigParams({
            crOpening: state.config.crOpening,
            crLiquidation: state.config.crLiquidation,
            minimumCreditBorrowAToken: state.config.minimumCreditBorrowAToken,
            collateralSplitLiquidatorPercent: state.config.collateralSplitLiquidatorPercent,
            collateralSplitProtocolPercent: state.config.collateralSplitProtocolPercent,
            collateralTokenCap: state.config.collateralTokenCap,
            borrowATokenCap: state.config.borrowATokenCap,
            debtTokenCap: state.config.debtTokenCap,
            repayFeeAPR: state.config.repayFeeAPR,
            earlyLenderExitFee: state.config.earlyLenderExitFee,
            earlyBorrowerExitFee: state.config.earlyBorrowerExitFee,
            collateralOverdueTransferFee: state.config.collateralOverdueTransferFee,
            feeRecipient: state.config.feeRecipient
        });
    }

    function oracle() external view returns (InitializeOracleParams memory) {
        return InitializeOracleParams({
            priceFeed: address(state.oracle.priceFeed),
            marketBorrowRateFeed: address(state.oracle.marketBorrowRateFeed)
        });
    }

    function data() external view returns (InitializeDataParams memory) {
        return InitializeDataParams({
            underlyingCollateralToken: address(state.data.underlyingCollateralToken),
            underlyingBorrowToken: address(state.data.underlyingBorrowToken),
            variablePool: address(state.data.variablePool)
        });
    }

    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state.data.users[user],
            account: user,
            collateralAmount: state.data.collateralToken.balanceOf(user),
            borrowAmount: state.borrowATokenBalanceOf(user),
            debtAmount: state.data.debtToken.balanceOf(user)
        });
    }

    function getVaultAddress(address user) external view returns (address) {
        return address(state.data.users[user].vault);
    }

    function activeLoans() external view returns (uint256) {
        return state.data.loans.length;
    }

    function isFOL(uint256 loanId) external view returns (bool) {
        return state.data.loans[loanId].isFOL();
    }

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return state.data.loans[loanId];
    }

    function getLoans() external view returns (Loan[] memory) {
        return state.data.loans;
    }

    function getLoanStatus(uint256 loanId) external view returns (LoanStatus) {
        return state.getLoanStatus(state.data.loans[loanId]);
    }

    function partialRepayFee(uint256 loanId, uint256 repayAmount) public view returns (uint256) {
        return state.partialRepayFee(state.data.loans[loanId], repayAmount);
    }

    function maximumRepayFee(uint256 loanId) external view returns (uint256) {
        return state.maximumRepayFee(state.data.loans[loanId]);
    }

    function maximumRepayFee(uint256 issuanceValue, uint256 startDate, uint256 dueDate)
        external
        view
        returns (uint256)
    {
        return state.maximumRepayFee(issuanceValue, startDate, dueDate);
    }

    function tokens() external view returns (NonTransferrableToken, IAToken, NonTransferrableToken) {
        return (state.data.collateralToken, state.data.borrowAToken, state.data.debtToken);
    }
}
