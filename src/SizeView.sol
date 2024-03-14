// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {UpdateConfig} from "@src/libraries/general/actions/UpdateConfig.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/general/actions/Initialize.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

struct UserView {
    User user;
    address account;
    uint256 collateralTokenBalanceFixed;
    uint256 collateralATokenBalanceVariable;
    uint256 borrowATokenBalanceFixed;
    uint256 borrowATokenBalanceVariable;
    uint256 debtBalanceFixed;
    uint256 debtBalanceVariable;
}

/// @title SizeView
/// @notice View methods for the Size protocol
abstract contract SizeView is SizeStorage {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using RiskLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;
    using UpdateConfig for State;

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
        return fol.getDebt();
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

    function feeConfig() external view returns (InitializeFeeConfigParams memory) {
        return state.feeConfigParams();
    }

    function riskConfig() external view returns (InitializeRiskConfigParams memory) {
        return state.riskConfigParams();
    }

    function oracle() external view returns (InitializeOracleParams memory) {
        return state.oracleParams();
    }

    function data() external view returns (InitializeDataParams memory) {
        return state.dataParams();
    }

    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state.data.users[user],
            account: user,
            collateralTokenBalanceFixed: state.data.collateralToken.balanceOf(user),
            collateralATokenBalanceVariable: state.aTokenBalanceOf(state.data.collateralAToken, user, true),
            borrowATokenBalanceFixed: state.aTokenBalanceOf(state.data.borrowAToken, user, false),
            borrowATokenBalanceVariable: state.aTokenBalanceOf(state.data.borrowAToken, user, true),
            debtBalanceFixed: state.data.debtToken.balanceOf(user),
            debtBalanceVariable: state.variableDebtTokenBalanceOf(user)
        });
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
        Loan storage loan = state.data.loans[loanId];
        Loan storage fol = state.getFOL(loan);
        return fol.partialRepayFee(repayAmount);
    }

    function repayFee(uint256 loanId) external view returns (uint256) {
        Loan storage loan = state.data.loans[loanId];
        Loan storage fol = state.getFOL(loan);
        return fol.repayFee();
    }

    function repayFee(uint256 issuanceValue, uint256 startDate, uint256 dueDate, uint256 repayFeeAPR)
        external
        pure
        returns (uint256)
    {
        return LoanLibrary.repayFee(issuanceValue, startDate, dueDate, repayFeeAPR);
    }

    function tokens() external view returns (NonTransferrableToken, IAToken, NonTransferrableToken) {
        return (state.data.collateralToken, state.data.borrowAToken, state.data.debtToken);
    }
}
