// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
}

library Repay {
    using LoanLibrary for Loan;
    using Common for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        Loan storage loan = state.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, loan.borrower);
        }
        if (state.tokens.borrowToken.balanceOf(msg.sender) < loan.faceValue) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.tokens.borrowToken.balanceOf(msg.sender), loan.faceValue);
        }

        // validate loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_REPAID(params.loanId);
        }
        if (state.either(loan, [LoanStatus.REPAID, LoanStatus.CLAIMED])) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanId);
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        Loan storage loan = state.loans[params.loanId];

        state.tokens.borrowToken.transferFrom(msg.sender, state.config.variablePool, loan.faceValue);
        state.tokens.debtToken.burn(msg.sender, loan.faceValue);
        loan.repaid = true;

        emit Events.Repay(params.loanId);
    }
}
