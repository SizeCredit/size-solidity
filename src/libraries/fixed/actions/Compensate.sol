// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {Math} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {
    CreditPosition, DebtPosition, LoanLibrary, LoanStatus, RESERVED_ID
} from "@src/libraries/fixed/LoanLibrary.sol";

import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

struct CompensateParams {
    uint256 creditPositionWithDebtToRepayId;
    uint256 creditPositionToCompensateId;
    uint256 amount;
}

library Compensate {
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;

    using RiskLibrary for State;

    function validateCompensate(State storage state, CompensateParams calldata params) external view {
        uint256 creditPositionWithDebtToRepayId = params.creditPositionWithDebtToRepayId;
        uint256 creditPositionToCompensateId = params.creditPositionToCompensateId == RESERVED_ID
            ? (state.data.nextCreditPositionId - 1)
            : params.creditPositionToCompensateId;

        CreditPosition storage creditPositionWithDebtToRepay = state.getCreditPosition(creditPositionWithDebtToRepayId);
        DebtPosition storage debtPositionToRepay =
            state.getDebtPositionByCreditPositionId(creditPositionWithDebtToRepayId);
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(creditPositionToCompensateId);
        DebtPosition storage debtPositionToCompensate =
            state.getDebtPositionByCreditPositionId(creditPositionToCompensateId);

        uint256 amountToCompensate =
            Math.min(params.amount, creditPositionToCompensate.credit, creditPositionWithDebtToRepay.credit);

        // validate creditPositionWithDebtToRepayId
        if (state.getLoanStatus(creditPositionWithDebtToRepayId) != LoanStatus.ACTIVE) {
            revert Errors.LOAN_NOT_ACTIVE(creditPositionWithDebtToRepayId);
        }

        // validate creditPositionToCompensateId
        if (!state.isCreditPositionTransferrable(creditPositionToCompensateId)) {
            revert Errors.CREDIT_POSITION_NOT_TRANSFERRABLE(
                creditPositionToCompensateId,
                state.getLoanStatus(creditPositionToCompensateId),
                state.collateralRatio(debtPositionToCompensate.borrower)
            );
        }
        if (debtPositionToRepay.dueDate < state.getDebtPositionByCreditPositionId(creditPositionToCompensateId).dueDate)
        {
            revert Errors.DUE_DATE_NOT_COMPATIBLE(creditPositionWithDebtToRepayId, creditPositionToCompensateId);
        }
        if (creditPositionToCompensate.lender != debtPositionToRepay.borrower) {
            revert Errors.INVALID_LENDER(creditPositionToCompensate.lender);
        }
        if (creditPositionToCompensateId == creditPositionWithDebtToRepayId) {
            revert Errors.INVALID_CREDIT_POSITION_ID(creditPositionToCompensateId);
        }

        // validate msg.sender
        if (msg.sender != debtPositionToRepay.borrower) {
            revert Errors.COMPENSATOR_IS_NOT_BORROWER(msg.sender, debtPositionToRepay.borrower);
        }

        // validate amount
        if (amountToCompensate == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeCompensate(State storage state, CompensateParams calldata params) external {
        uint256 creditPositionWithDebtToRepayId = params.creditPositionWithDebtToRepayId;
        uint256 creditPositionToCompensateId = params.creditPositionToCompensateId == RESERVED_ID
            ? (state.data.nextCreditPositionId - 1)
            : params.creditPositionToCompensateId;

        emit Events.Compensate(creditPositionWithDebtToRepayId, creditPositionToCompensateId, params.amount);

        CreditPosition storage creditPositionWithDebtToRepay = state.getCreditPosition(creditPositionWithDebtToRepayId);
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(creditPositionToCompensateId);

        uint256 amountToCompensate =
            Math.min(params.amount, creditPositionToCompensate.credit, creditPositionWithDebtToRepay.credit);

        // debt reduction
        state.repayDebt(creditPositionWithDebtToRepay.debtPositionId, amountToCompensate, false);

        // credit reduction
        // slither-disable-next-line unused-return
        state.reduceCredit(creditPositionWithDebtToRepayId, amountToCompensate);

        uint256 exiterCreditRemaining = creditPositionToCompensate.credit - amountToCompensate;

        // credit emission
        state.createCreditPosition({
            exitCreditPositionId: creditPositionToCompensateId,
            lender: creditPositionWithDebtToRepay.lender,
            credit: amountToCompensate
        });
        if (exiterCreditRemaining > 0) {
            // charge the fragmentation fee in collateral tokens, capped by the user balance
            uint256 fragmentationFeeInCollateral = Math.min(
                state.debtTokenAmountToCollateralTokenAmount(state.feeConfig.fragmentationFee),
                state.data.collateralToken.balanceOf(msg.sender)
            );
            state.data.collateralToken.transferFrom(
                msg.sender, state.feeConfig.feeRecipient, fragmentationFeeInCollateral
            );
        }
    }
}
