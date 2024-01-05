// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {Math} from "@src/libraries/MathLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Common} from "@src/libraries/actions/Common.sol";

struct CompensateParams {
    uint256 loanToRepayId;
    uint256 loanToCompensateId;
    uint256 amount;
}

library Compensate {
    using Common for State;
    using LoanLibrary for Loan;

    function validateCompensate(State storage state, CompensateParams calldata params) external view {
        Loan memory loanToRepay = state.loans[params.loanToRepayId];
        Loan memory loanToCompensate = state.loans[params.loanToCompensateId];

        // validate msg.sender
        if (msg.sender != loanToRepay.borrower) {
            revert Errors.COMPENSATOR_IS_NOT_BORROWER(msg.sender, loanToRepay.borrower);
        }

        // validate loanToRepayId
        if (loanToRepay.repaid) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanToRepayId);
        }

        // validate loanToCompensateId
        if (loanToCompensate.repaid) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanToCompensateId);
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
        Loan storage loanToRepay = state.loans[params.loanToRepayId];
        Loan storage loanToCompensate = state.loans[params.loanToCompensateId];
        // @audit Check the implications of a user-provided compensation amount
        uint256 amountToCompensate = Math.min(params.amount, loanToCompensate.getCredit(), loanToRepay.getCredit());

        state.reduceDebt(params.loanToRepayId, amountToCompensate);

        state.createSOL({
            exiterId: params.loanToCompensateId,
            lender: loanToRepay.lender,
            borrower: msg.sender,
            faceValue: amountToCompensate
        });
    }
}
