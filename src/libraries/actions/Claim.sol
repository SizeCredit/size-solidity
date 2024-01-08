// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 loanId;
}

library Claim {
    using LoanLibrary for Loan;
    using Common for State;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        Loan storage loan = state.loans[params.loanId];

        // validate msg.sender
        // @audit Check if this should be permissioned

        // validate loanId
        if (state.getLoanStatus(loan) != LoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.loanId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        Loan storage loan = state.loans[params.loanId];

        state.tokens.borrowToken.transferFrom(state.config.variablePool, loan.lender, loan.getCredit());
        loan.faceValueExited = loan.faceValue;

        emit Events.Claim(params.loanId);
    }
}
