// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {Math} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct CompensateParams {
    uint256 loanToRepayId;
    uint256 loanToCompensateId;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
}

library Compensate {
    using AccountingLibrary for State;
    using FixedLoanLibrary for State;
    using FixedLoanLibrary for FixedLoan;

    function validateCompensate(State storage state, CompensateParams calldata params) external view {
        FixedLoan storage loanToRepay = state._fixed.loans[params.loanToRepayId];
        FixedLoan storage loanToCompensate = state._fixed.loans[params.loanToCompensateId];

        // validate msg.sender
        if (msg.sender != loanToRepay.borrower) {
            revert Errors.COMPENSATOR_IS_NOT_BORROWER(msg.sender, loanToRepay.borrower);
        }

        // validate loanToRepayId
        if (state.getFixedLoanStatus(loanToRepay) == FixedLoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanToRepayId);
        }

        // validate loanToCompensateId
        if (state.getFixedLoanStatus(loanToCompensate) == FixedLoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanToCompensateId);
        }
        if (
            state.getFixedLoanStatus(loanToCompensate) != FixedLoanStatus.REPAID
                && loanToRepay.dueDate < loanToCompensate.dueDate
        ) {
            revert Errors.DUE_DATE_NOT_COMPATIBLE(params.loanToRepayId, params.loanToCompensateId);
        }
        if (loanToCompensate.lender != loanToRepay.borrower) {
            revert Errors.INVALID_LENDER(loanToCompensate.lender);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeCompensate(State storage state, CompensateParams calldata params) external {
        emit Events.Compensate(params.loanToRepayId, params.loanToCompensateId, params.amount);

        FixedLoan storage loanToRepay = state._fixed.loans[params.loanToRepayId];
        FixedLoan storage loanToCompensate = state._fixed.loans[params.loanToCompensateId];
        uint256 amountToCompensate = Math.min(params.amount, loanToCompensate.credit, loanToRepay.credit);

        state.reduceDebt(params.loanToRepayId, amountToCompensate);
        state.reduceCredit(params.loanToRepayId, amountToCompensate);

        state.createSOL({
            exiterId: params.loanToCompensateId,
            lender: loanToRepay.lender,
            borrower: msg.sender,
            issuanceValue: amountToCompensate, // @audit review if this is the same as faceValue
            faceValue: amountToCompensate
        });
    }
}
