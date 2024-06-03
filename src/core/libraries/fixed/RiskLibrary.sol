// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/core/SizeStorage.sol";

import {Errors} from "@src/core/libraries/Errors.sol";

import {Math} from "@src/core/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/core/libraries/fixed/LoanLibrary.sol";

/// @title RiskLibrary
library RiskLibrary {
    using LoanLibrary for State;

    function validateMinimumCredit(State storage state, uint256 credit) public view {
        if (0 < credit && credit < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state.riskConfig.minimumCreditBorrowAToken);
        }
    }

    function validateMinimumCreditOpening(State storage state, uint256 credit) public view {
        if (credit < state.riskConfig.minimumCreditBorrowAToken) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING(credit, state.riskConfig.minimumCreditBorrowAToken);
        }
    }

    function validateTenor(State storage state, uint256 tenor) public view {
        if (tenor < state.riskConfig.minTenor || tenor > state.riskConfig.maxTenor) {
            revert Errors.TENOR_OUT_OF_RANGE(tenor, state.riskConfig.minTenor, state.riskConfig.maxTenor);
        }
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state.data.collateralToken.balanceOf(account);
        uint256 debt = state.data.debtToken.balanceOf(account);
        uint256 debtWad = Math.amountToWad(debt, state.data.underlyingBorrowToken.decimals());
        uint256 price = state.oracle.priceFeed.getPrice();

        if (debt != 0) {
            return Math.mulDivDown(collateral, price, debtWad);
        } else {
            return type(uint256).max;
        }
    }

    function isCreditPositionSelfLiquidatable(State storage state, uint256 creditPositionId)
        public
        view
        returns (bool)
    {
        CreditPosition storage creditPosition = state.data.creditPositions[creditPositionId];
        DebtPosition storage debtPosition = state.data.debtPositions[creditPosition.debtPositionId];
        LoanStatus status = state.getLoanStatus(creditPositionId);
        // Only CreditPositions can be self liquidated
        return state.isCreditPositionId(creditPositionId)
            && (isUserUnderwater(state, debtPosition.borrower) && status != LoanStatus.REPAID);
    }

    function isCreditPositionTransferrable(State storage state, uint256 creditPositionId)
        internal
        view
        returns (bool)
    {
        return state.getLoanStatus(creditPositionId) == LoanStatus.ACTIVE
            && !isUserUnderwater(state, state.getDebtPositionByCreditPositionId(creditPositionId).borrower);
    }

    function isDebtPositionLiquidatable(State storage state, uint256 debtPositionId) public view returns (bool) {
        DebtPosition storage debtPosition = state.data.debtPositions[debtPositionId];
        LoanStatus status = state.getLoanStatus(debtPositionId);
        // only DebtPositions can be liquidated
        return state.isDebtPositionId(debtPositionId)
        // case 1: if the user is underwater, only ACTIVE/OVERDUE DebtPositions can be liquidated
        && (
            (isUserUnderwater(state, debtPosition.borrower) && status != LoanStatus.REPAID)
            // case 2: overdue loans can always be liquidated regardless of the user's CR
            || status == LoanStatus.OVERDUE
        );
    }

    function isUserUnderwater(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state.riskConfig.crLiquidation;
    }

    function validateUserIsNotUnderwater(State storage state, address account) external view {
        if (isUserUnderwater(state, account)) {
            revert Errors.USER_IS_UNDERWATER(account, collateralRatio(state, account));
        }
    }

    function validateUserIsNotBelowOpeningLimitBorrowCR(State storage state, address account) external view {
        uint256 openingLimitBorrowCR = Math.max(
            state.riskConfig.crOpening,
            state.data.users[account].openingLimitBorrowCR // 0 by default, or user-defined if SetUserConfiguration has been used
        );
        if (collateralRatio(state, account) < openingLimitBorrowCR) {
            revert Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR(
                account, collateralRatio(state, account), openingLimitBorrowCR
            );
        }
    }
}
