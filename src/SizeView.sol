// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SizeStorage, State} from "@src/SizeStorage.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {FeeLibrary} from "@src/libraries/fixed/FeeLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

import {BorrowOffer, FixedLoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {User} from "@src/libraries/fixed/UserLibrary.sol";
import {
    InitializeFixedParams,
    InitializeGeneralParams,
    InitializeVariableParams
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
    using OfferLibrary for FixedLoanOffer;
    using OfferLibrary for BorrowOffer;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;
    using RiskLibrary for State;
    using VariableLibrary for State;
    using FeeLibrary for State;

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
        FixedLoan memory loan = state._fixed.loans[loanId];
        return state.getFOLAssignedCollateral(loan);
    }

    function getDebt(uint256 loanId) external view returns (uint256) {
        return state._fixed.loans[loanId].debt;
    }

    function getCredit(uint256 loanId) external view returns (uint256) {
        return state._fixed.loans[loanId].credit;
    }

    function generalConfig() external view returns (InitializeGeneralParams memory) {
        return InitializeGeneralParams({
            owner: address(0), // TODO return correct owner
            priceFeed: address(state._general.priceFeed),
            marketBorrowRateFeed: address(state._general.marketBorrowRateFeed),
            collateralAsset: address(state._general.collateralAsset),
            borrowAsset: address(state._general.borrowAsset),
            feeRecipient: state._general.feeRecipient,
            variablePool: address(state._general.variablePool)
        });
    }

    function fixedConfig() external view returns (InitializeFixedParams memory) {
        return InitializeFixedParams({
            crOpening: state._fixed.crOpening,
            crLiquidation: state._fixed.crLiquidation,
            collateralSplitLiquidatorPercent: state._fixed.collateralSplitLiquidatorPercent,
            collateralSplitProtocolPercent: state._fixed.collateralSplitProtocolPercent,
            minimumCreditBorrowAsset: state._fixed.minimumCreditBorrowAsset,
            collateralTokenCap: state._fixed.collateralTokenCap,
            borrowATokenCap: state._fixed.borrowATokenCap,
            debtTokenCap: state._fixed.debtTokenCap,
            repayFeeAPR: state._fixed.repayFeeAPR,
            earlyLenderExitFee: state._fixed.earlyLenderExitFee,
            earlyBorrowerExitFee: state._fixed.earlyBorrowerExitFee
        });
    }

    function variableConfig() external view returns (InitializeVariableParams memory) {
        return InitializeVariableParams({collateralOverdueTransferFee: state._variable.collateralOverdueTransferFee});
    }

    function getUserView(address user) external view returns (UserView memory) {
        return UserView({
            user: state._fixed.users[user],
            account: user,
            collateralAmount: state._fixed.collateralToken.balanceOf(user),
            borrowAmount: state.borrowATokenBalanceOf(user),
            debtAmount: state._fixed.debtToken.balanceOf(user)
        });
    }

    function getVaultAddress(address user) external view returns (address) {
        return address(state._fixed.users[user].vault);
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

    function repayFee(uint256 loanId, uint256 repayAmount) public view returns (uint256) {
        return state.currentRepayFee(state._fixed.loans[loanId], repayAmount);
    }

    function maximumRepayFee(uint256 loanId) external view returns (uint256) {
        FixedLoan memory loan = state._fixed.loans[loanId];
        return state.maximumRepayFee(loan);
    }

    function tokens() external view returns (NonTransferrableToken, IAToken, NonTransferrableToken) {
        return (state._fixed.collateralToken, state._fixed.borrowAToken, state._fixed.debtToken);
    }
}
