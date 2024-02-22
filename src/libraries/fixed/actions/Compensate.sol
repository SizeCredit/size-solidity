// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {Math} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

struct CompensateParams {
    uint256 debtPositionToRepayId;
    uint256 creditPositionToCompensateId;
    uint256 amount;
}

library Compensate {
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using VariableLibrary for State;

    function validateCompensate(State storage state, CompensateParams calldata params) external view {
        DebtPosition storage debtPositionToRepay = state.getDebtPosition(params.debtPositionToRepayId);
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(params.creditPositionToCompensateId);

        // validate debtPositionToRepayId
        if (state.getLoanStatus(params.debtPositionToRepayId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionToRepayId);
        }

        // validate creditPositionToCompensateId
        if (state.getLoanStatus(params.creditPositionToCompensateId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.creditPositionToCompensateId);
        }
        if (
            debtPositionToRepay.dueDate
                < state.getDebtPositionByCreditPositionId(params.creditPositionToCompensateId).dueDate
        ) {
            revert Errors.DUE_DATE_NOT_COMPATIBLE(params.debtPositionToRepayId, params.creditPositionToCompensateId);
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
        emit Events.Compensate(params.debtPositionToRepayId, params.creditPositionToCompensateId, params.amount);

        DebtPosition storage debtPositionToRepay = state.getDebtPosition(params.debtPositionToRepayId);
        CreditPosition storage creditPositionToCompensate = state.getCreditPosition(params.creditPositionToCompensateId);

        uint256 amountToCompensate =
            Math.min(params.amount, creditPositionToCompensate.credit, debtPositionToRepay.faceValue());

        state.chargeRepayFeeInCollateral(debtPositionToRepay, amountToCompensate);
        state.data.debtToken.burn(debtPositionToRepay.borrower, amountToCompensate);
        if (debtPositionToRepay.getDebt() == 0) {
            debtPositionToRepay.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        }

        // slither-disable-next-line unused-return
        state.createCreditPosition({
            exitCreditPositionId: params.creditPositionToCompensateId,
            lender: debtPositionToRepay.lender,
            borrower: msg.sender,
            credit: amountToCompensate
        });
    }
}
