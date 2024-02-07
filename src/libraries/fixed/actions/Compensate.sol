// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {Math, PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

struct CompensateParams {
    uint256 loanToRepayId;
    uint256 loanToCompensateId;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
}

library Compensate {
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for Loan;
    using VariableLibrary for State;

    function validateCompensate(State storage state, CompensateParams calldata params) external view {
        Loan storage loanToRepay = state.data.loans[params.loanToRepayId];
        Loan storage loanToCompensate = state.data.loans[params.loanToCompensateId];

        // validate msg.sender
        if (msg.sender != loanToRepay.generic.borrower) {
            revert Errors.COMPENSATOR_IS_NOT_BORROWER(msg.sender, loanToRepay.generic.borrower);
        }

        // validate loanToRepayId
        if (!loanToRepay.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_COMPENSATED(params.loanToRepayId);
        }
        if (state.getLoanStatus(loanToRepay) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanToRepayId);
        }

        // validate loanToCompensateId
        if (state.getLoanStatus(loanToCompensate) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanToCompensateId);
        }
        if (
            state.getLoanStatus(loanToCompensate) != LoanStatus.REPAID
                && loanToRepay.fol.dueDate < state.getFOL(loanToCompensate).fol.dueDate
        ) {
            revert Errors.DUE_DATE_NOT_COMPATIBLE(params.loanToRepayId, params.loanToCompensateId);
        }
        if (loanToCompensate.generic.lender != loanToRepay.generic.borrower) {
            revert Errors.INVALID_LENDER(loanToCompensate.generic.lender);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeCompensate(State storage state, CompensateParams calldata params) external {
        emit Events.Compensate(params.loanToRepayId, params.loanToCompensateId, params.amount);

        Loan storage loanToRepay = state.data.loans[params.loanToRepayId];
        Loan storage loanToCompensate = state.data.loans[params.loanToCompensateId];
        uint256 amountToCompensate = Math.min(params.amount, loanToCompensate.generic.credit, loanToRepay.faceValue());

        state.chargeRepayFee(loanToRepay, amountToCompensate);
        state.data.debtToken.burn(loanToRepay.generic.borrower, amountToCompensate);
        if (state.getDebt(loanToRepay) == 0) {
            loanToCompensate.fol.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        }

        // slither-disable-next-line unused-return
        state.createSOL({
            exiterId: params.loanToCompensateId,
            lender: loanToRepay.generic.lender,
            borrower: msg.sender,
            credit: amountToCompensate
        });
    }
}
