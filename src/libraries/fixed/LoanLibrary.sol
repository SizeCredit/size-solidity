// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

uint256 constant DEBT_POSITION_ID_START = 0;
uint256 constant CREDIT_POSITION_ID_START = type(uint256).max / 2;
uint256 constant RESERVED_ID = type(uint256).max;

struct DebtPosition {
    address lender;
    address borrower;
    uint256 issuanceValue; // updated on debt reduction
    uint256 faceValue; // updated on debt reduction
    uint256 repayFee; // updated on debt reduction
    uint256 overdueLiquidatorReward; // only paid in case of overdue liquidation
    uint256 startDate; // updated on borrower replacement
    uint256 dueDate;
    uint256 liquidityIndexAtRepayment; // set on full repayment
}

struct CreditPosition {
    address lender;
    uint256 credit;
    uint256 debtPositionId;
}

// When the loan is created, it is in ACTIVE status
// When maturity is reached, it is in OVERDUE status and subject to liquidation
// When the loan is repaid either by the borrower or by the liquidator, it is in REPAID status
enum LoanStatus {
    ACTIVE, // not yet due
    OVERDUE, // eligible to liquidation
    REPAID // by borrower or liquidator

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

    /// @notice Get the pro-rata debt amount for a partial repayment
    /// @dev This function should only be used to calculate the amount to clear from the borrower debt tracker
    ///      The overdueCollateralReward is not cleared be zero if the loan has not been fully repaid
    function getDebtProRata(DebtPosition memory self, uint256 repayAmount, uint256 repayFeeProRata)
        internal
        pure
        returns (uint256)
    {
        return repayAmount + repayFeeProRata + self.faceValue == repayAmount ? self.overdueLiquidatorReward : 0;
    }

    /// @notice Get the total debt of a DebtPosition
    ///         The total loan debt is the face value (debt to the lender)
    ///        + the repay fee (protocol fee)
    ///        + the overdue liquidator reward (in case of overdue liquidation).
    /// @dev   The overdue liquidatorreward is only paid in case of overdue liquidation, but
    ///        it is included in the total debt so that it is properly collateralized.
    ///        In case of a repayment before the due date, the reward is deducted from borrower debt tracker.
    /// @param self The DebtPosition
    function getDebt(DebtPosition memory self) internal pure returns (uint256) {
        return self.faceValue + self.repayFee + self.overdueLiquidatorReward;
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
        if (getDebt(debtPosition) == 0) {
            return LoanStatus.REPAID;
        } else if (block.timestamp > debtPosition.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    /// @notice Get the amount of collateral assigned to a DebtPosition
    /// @dev Takes into account the total debt of the user, which includes the repayment fee and the overdue collateral reward
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
            return Math.mulDivDown(collateral, debtPosition.faceValue, debt);
        } else {
            return 0;
        }
    }

    /// @notice Get the amount of collateral assigned to a CreditPosition, pro-rata to the DebtPosition's faceValue
    /// @dev Takes into account the total debt of the user, which includes the repayment fee
    /// @param state The state struct
    /// @param creditPosition The CreditPosition
    /// @return The amount of collateral assigned to the CreditPosition
    function getCreditPositionProRataAssignedCollateral(State storage state, CreditPosition memory creditPosition)
        public
        view
        returns (uint256)
    {
        DebtPosition storage debtPosition = getDebtPosition(state, creditPosition.debtPositionId);

        uint256 creditPositionCredit = creditPosition.credit;
        uint256 debtPositionCollateral = getDebtPositionAssignedCollateral(state, debtPosition);
        uint256 debtPositionFaceValue = debtPosition.faceValue;

        if (debtPositionFaceValue != 0) {
            return Math.mulDivDown(debtPositionCollateral, creditPositionCredit, debtPositionFaceValue);
        } else {
            return 0;
        }
    }

    function updateRepayFee(DebtPosition storage self, uint256 _repayAmount, uint256 _repayFee) external {
        uint256 r = Math.mulDivDown(PERCENT, self.faceValue, self.issuanceValue);
        self.faceValue -= _repayAmount;
        self.repayFee -= _repayFee;
        self.issuanceValue = Math.mulDivDown(self.faceValue, PERCENT, r);
    }

    function repayFee(uint256 issuanceValue, uint256 startDate, uint256 dueDate, uint256 repayFeeAPR)
        internal
        pure
        returns (uint256)
    {
        uint256 interval = dueDate - startDate;
        uint256 repayFeePercent = Math.mulDivUp(repayFeeAPR, interval, 365 days);
        uint256 fee = Math.mulDivUp(issuanceValue, repayFeePercent, PERCENT);
        return fee;
    }

    /// @notice Calculate the early repayment fee for a DebtPosition
    /// @dev The fee is calculated as a fraction of the total repayment fee, based on the time elapsed since the loan start date
    ///      The early repay fee applies to a borrower exit only
    /// @param self The DebtPosition
    function earlyRepayFee(DebtPosition memory self) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - self.startDate;
        uint256 maturity = self.dueDate - self.startDate;
        return Math.mulDivDown(self.repayFee, elapsed, maturity);
    }
}
