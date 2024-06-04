// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/core/SizeStorage.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Math} from "@src/core/libraries/Math.sol";
import {AccountingLibrary} from "@src/core/libraries/fixed/AccountingLibrary.sol";

uint256 constant DEBT_POSITION_ID_START = 0;
uint256 constant CREDIT_POSITION_ID_START = type(uint256).max / 2;
uint256 constant RESERVED_ID = type(uint256).max;

struct DebtPosition {
    address borrower;
    uint256 futureValue; // updated on debt reduction
    uint256 dueDate;
    uint256 liquidityIndexAtRepayment; // set on full repayment
}

struct CreditPosition {
    address lender;
    bool forSale;
    uint256 credit;
    uint256 debtPositionId;
}

// When the loan is created, it is in ACTIVE status
// When tenor is reached, it is in OVERDUE status and subject to liquidation
// When the loan is repaid either by the borrower or by the liquidator, it is in REPAID status
enum LoanStatus {
    ACTIVE,
    OVERDUE,
    REPAID
}

/// @title LoanLibrary
library LoanLibrary {
    using AccountingLibrary for State;

    function isDebtPositionId(State storage state, uint256 positionId) internal view returns (bool) {
        return positionId >= DEBT_POSITION_ID_START && positionId < state.data.nextDebtPositionId;
    }

    function isCreditPositionId(State storage state, uint256 positionId) internal view returns (bool) {
        return positionId >= CREDIT_POSITION_ID_START && positionId < state.data.nextCreditPositionId;
    }

    function getDebtPositionIdByCreditPositionId(State storage state, uint256 creditPositionId)
        public
        view
        returns (uint256)
    {
        return getCreditPosition(state, creditPositionId).debtPositionId;
    }

    function getDebtPosition(State storage state, uint256 debtPositionId) public view returns (DebtPosition storage) {
        if (isDebtPositionId(state, debtPositionId)) {
            return state.data.debtPositions[debtPositionId];
        } else {
            revert Errors.INVALID_DEBT_POSITION_ID(debtPositionId);
        }
    }

    function getCreditPosition(State storage state, uint256 creditPositionId)
        public
        view
        returns (CreditPosition storage)
    {
        if (isCreditPositionId(state, creditPositionId)) {
            return state.data.creditPositions[creditPositionId];
        } else {
            revert Errors.INVALID_CREDIT_POSITION_ID(creditPositionId);
        }
    }

    function getDebtPositionByCreditPositionId(State storage state, uint256 creditPositionId)
        public
        view
        returns (DebtPosition storage)
    {
        CreditPosition memory creditPosition = getCreditPosition(state, creditPositionId);
        return getDebtPosition(state, creditPosition.debtPositionId);
    }

    /// @notice Get the status of a loan
    /// @param state The state struct
    /// @param positionId The positionId (can be either a DebtPosition or a CreditPosition)
    /// @return The status of the loan
    function getLoanStatus(State storage state, uint256 positionId) public view returns (LoanStatus) {
        // assumes `positionId` is a debt position id
        DebtPosition memory debtPosition = state.data.debtPositions[positionId];
        if (isCreditPositionId(state, positionId)) {
            // if `positionId` is in reality a credit position id, updates the memory variable
            debtPosition = getDebtPositionByCreditPositionId(state, positionId);
        } else if (!isDebtPositionId(state, positionId)) {
            // if `positionId` is neither a debt position id nor a credit position id, reverts
            revert Errors.INVALID_POSITION_ID(positionId);
        }

        // slither-disable-next-line incorrect-equality
        if (debtPosition.futureValue == 0) {
            return LoanStatus.REPAID;
        } else if (block.timestamp > debtPosition.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    /// @notice Get the amount of collateral assigned to a DebtPosition
    /// @param state The state struct
    /// @param debtPosition The DebtPosition
    /// @return The amount of collateral assigned to the DebtPosition
    function getDebtPositionAssignedCollateral(State storage state, DebtPosition memory debtPosition)
        public
        view
        returns (uint256)
    {
        uint256 debt = state.data.debtToken.balanceOf(debtPosition.borrower);
        uint256 collateral = state.data.collateralToken.balanceOf(debtPosition.borrower);

        if (debt != 0) {
            return Math.mulDivDown(collateral, debtPosition.futureValue, debt);
        } else {
            return 0;
        }
    }

    /// @notice Get the amount of collateral assigned to a CreditPosition, pro-rata to the DebtPosition's futureValue
    /// @param state The state struct
    /// @param creditPosition The CreditPosition
    /// @return The amount of collateral assigned to the CreditPosition
    function getCreditPositionProRataAssignedCollateral(State storage state, CreditPosition memory creditPosition)
        public
        view
        returns (uint256)
    {
        DebtPosition storage debtPosition = getDebtPosition(state, creditPosition.debtPositionId);

        uint256 debtPositionCollateral = getDebtPositionAssignedCollateral(state, debtPosition);
        uint256 creditPositionCredit = creditPosition.credit;
        uint256 debtPositionFutureValue = debtPosition.futureValue;

        if (debtPositionFutureValue != 0) {
            return Math.mulDivDown(debtPositionCollateral, creditPositionCredit, debtPositionFutureValue);
        } else {
            return 0;
        }
    }
}
