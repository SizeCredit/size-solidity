// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
    address borrower;
}

library Repay {
    using LoanLibrary for Loan;

    function validateRepay(State storage state, RepayParams memory params) external view {
        Loan memory loan = state.loans[params.loanId];

        // validate loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_REPAID(params.loanId);
        }
        if (loan.repaid) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanId);
        }

        // validate borrower
        if (params.borrower != loan.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(params.borrower, loan.borrower);
        }
        if (state.borrowToken.balanceOf(params.borrower) < loan.FV) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowToken.balanceOf(params.borrower), loan.FV);
        }

        // validate protocol
    }

    function executeRepay(State storage state, RepayParams memory params) external {
        Loan storage loan = state.loans[params.loanId];

        state.borrowToken.transferFrom(params.borrower, state.protocolVault, loan.FV);
        state.debtToken.burn(loan.borrower, loan.FV);
        loan.repaid = true;

        emit Events.Repay(params.loanId, params.borrower);
    }
}
