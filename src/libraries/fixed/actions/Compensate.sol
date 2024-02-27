// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {Math} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

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
    using VariableLibrary for State;
    using RiskLibrary for State;

    function validateCompensate(State storage state, CompensateParams calldata params) external view {
        CreditPosition storage creditPositionWithDebtToRepay =
            state.getCreditPosition(params.creditPositionWithDebtToRepayId);
        DebtPosition storage debtPositionToRepay =
            state.getDebtPositionByCreditPositionId(params.creditPositionWithDebtToRepayId);
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(params.creditPositionToCompensateId);

        uint256 amountToCompensate =
            Math.min(params.amount, creditPositionToCompensate.credit, debtPositionToRepay.faceValue);

        // validate creditPositionWithDebtToRepayId
        if (state.getLoanStatus(params.creditPositionWithDebtToRepayId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.creditPositionWithDebtToRepayId);
        }
        if (creditPositionWithDebtToRepay.credit < amountToCompensate) {
            revert Errors.CREDIT_LOWER_THAN_AMOUNT_TO_COMPENSATE(
                creditPositionWithDebtToRepay.credit, amountToCompensate
            );
        }

        // validate creditPositionToCompensateId
        if (state.getLoanStatus(params.creditPositionToCompensateId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.creditPositionToCompensateId);
        }
        if (
            debtPositionToRepay.dueDate
                < state.getDebtPositionByCreditPositionId(params.creditPositionToCompensateId).dueDate
        ) {
            revert Errors.DUE_DATE_NOT_COMPATIBLE(
                params.creditPositionWithDebtToRepayId, params.creditPositionToCompensateId
            );
        }
        if (creditPositionToCompensate.lender != debtPositionToRepay.borrower) {
            revert Errors.INVALID_LENDER(creditPositionToCompensate.lender);
        }

        // validate msg.sender
        if (msg.sender != debtPositionToRepay.borrower) {
            revert Errors.COMPENSATOR_IS_NOT_BORROWER(msg.sender, debtPositionToRepay.borrower);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeCompensate(State storage state, CompensateParams calldata params) external {
        emit Events.Compensate(
            params.creditPositionWithDebtToRepayId, params.creditPositionToCompensateId, params.amount
        );

        CreditPosition storage creditPositionWithDebtToRepay =
            state.getCreditPosition(params.creditPositionWithDebtToRepayId);
        DebtPosition storage debtPositionToRepay =
            state.getDebtPositionByCreditPositionId(params.creditPositionWithDebtToRepayId);
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(params.creditPositionToCompensateId);

        uint256 amountToCompensate =
            Math.min(params.amount, creditPositionToCompensate.credit, debtPositionToRepay.faceValue);

        // debt reduction
        state.chargeAndUpdateRepayFeeInCollateral(debtPositionToRepay, amountToCompensate);
        state.data.debtToken.burn(debtPositionToRepay.borrower, amountToCompensate);
        if (debtPositionToRepay.getDebt() == 0) {
            debtPositionToRepay.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        }
        creditPositionWithDebtToRepay.credit -= amountToCompensate;
        state.validateMinimumCredit(creditPositionWithDebtToRepay.credit);

        // credit emission
        // slither-disable-next-line unused-return
        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionToCompensateId,
            lender: debtPositionToRepay.lender,
            borrower: msg.sender,
            credit: amountToCompensate
        });
    }
}
