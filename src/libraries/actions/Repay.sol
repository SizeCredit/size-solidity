// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
}

library Repay {
    using LoanLibrary for Loan;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        Loan memory loan = state.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, loan.borrower);
        }
        if (state.borrowToken.balanceOf(msg.sender) < loan.faceValue) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowToken.balanceOf(msg.sender), loan.faceValue);
        }

        // validate loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_REPAID(params.loanId);
        }
        if (loan.repaid) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanId);
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        Loan storage loan = state.loans[params.loanId];

        state.borrowToken.transferFrom(msg.sender, state.protocolVault, loan.faceValue);
        state.debtToken.burn(loan.borrower, loan.faceValue);
        loan.repaid = true;

        emit Events.Repay(params.loanId);
    }
}
