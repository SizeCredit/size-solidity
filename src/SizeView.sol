// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {
    CREDIT_POSITION_ID_START,
    CreditPosition,
    DEBT_POSITION_ID_START,
    DebtPosition,
    LoanLibrary,
    LoanStatus
} from "@src/libraries/fixed/LoanLibrary.sol";
import {UpdateConfig} from "@src/libraries/general/actions/UpdateConfig.sol";

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

/// @title SizeView
/// @notice View methods for the Size protocol
abstract contract SizeView is SizeStorage {
    using OfferLibrary for LoanOffer;
    using OfferLibrary for BorrowOffer;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
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

    function getDebtPositionAssignedCollateral(uint256 debtPositionId) external view returns (uint256) {
        DebtPosition memory debtPosition = state.getDebtPosition(debtPositionId);
        return state.getDebtPositionAssignedCollateral(debtPosition);
    }

    function getDebt(uint256 positionId) external view returns (uint256) {
        return state.getDebtPosition(positionId).getDebt();
    }

    function faceValue(uint256 positionId) external view returns (uint256) {
        return state.getDebtPosition(positionId).faceValue();
    }

    function getDueDate(uint256 positionId) external view returns (uint256) {
        return state.getDebtPosition(positionId).dueDate;
    }

    function getCredit(uint256 creditPositionId) external view returns (uint256) {
        return state.data.creditPositions[creditPositionId].credit;
    }

    function config() external view returns (InitializeConfigParams memory) {
        return state.configParams();
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
            collateralAmount: state.data.collateralToken.balanceOf(user),
            borrowAmount: state.borrowATokenBalanceOf(user),
            debtAmount: state.data.debtToken.balanceOf(user)
        });
    }

    function getVaultAddress(address user) external view returns (address) {
        return address(state.data.users[user].vault);
    }

    function isDebtPositionId(uint256 debtPositionId) external view returns (bool) {
        return state.isDebtPositionId(debtPositionId);
    }

    function isCreditPositionId(uint256 creditPositionId) external view returns (bool) {
        return state.isCreditPositionId(creditPositionId);
    }

    function getDebtPosition(uint256 positionId) external view returns (DebtPosition memory) {
        return state.getDebtPosition(positionId);
    }

    function getCreditPosition(uint256 creditPositionId) external view returns (CreditPosition memory) {
        return state.data.creditPositions[creditPositionId];
    }

    function getLoanStatus(uint256 positionId) external view returns (LoanStatus) {
        return state.getLoanStatus(positionId);
    }

    function partialRepayFee(uint256 positionId, uint256 repayAmount) public view returns (uint256) {
        return state.getDebtPosition(positionId).partialRepayFee(repayAmount);
    }

    function repayFee(uint256 positionId) external view returns (uint256) {
        return state.getDebtPosition(positionId).repayFee();
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

    function getPositionsCount() external view returns (uint256, uint256) {
        return (
            state.data.nextDebtPositionId - DEBT_POSITION_ID_START,
            state.data.nextCreditPositionId - CREDIT_POSITION_ID_START
        );
    }
}
