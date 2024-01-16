// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";
import {Math} from "@src/libraries/MathLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
    uint256 amount;
}

library Repay {
    using FixedLoanLibrary for FixedLoan;
    using Common for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, loan.borrower);
        }
        if (state._fixed.borrowToken.balanceOf(msg.sender) < loan.faceValue) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state._fixed.borrowToken.balanceOf(msg.sender), loan.faceValue);
        }

        // validate loanId
        if (state.either(loan, [FixedLoanStatus.REPAID, FixedLoanStatus.CLAIMED])) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanId);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        FixedLoan storage loan = state._fixed.loans[params.loanId];
        uint256 repayAmount = Math.min(loan.faceValue, params.amount);

        if (repayAmount == loan.faceValue && loan.isFOL()) {
            state._fixed.borrowToken.transferFrom(msg.sender, state._general.variablePool, repayAmount);
            state._fixed.debtToken.burn(msg.sender, repayAmount);
            loan.repaid = true;
        } else {
            state._fixed.borrowToken.transferFrom(msg.sender, loan.lender, repayAmount);
            state.reduceDebt(params.loanId, repayAmount);
        }

        emit Events.Repay(params.loanId, repayAmount);
    }
}
