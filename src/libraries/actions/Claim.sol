// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedLoan} from "@src/libraries/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 loanId;
}

library Claim {
    using FixedLoanLibrary for FixedLoan;
    using Common for State;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        FixedLoan storage loan = state.loans[params.loanId];

        // validate msg.sender
        // @audit Check if this should be permissioned

        // validate loanId
        if (state.getFixedLoanStatus(loan) != FixedLoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.loanId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        FixedLoan storage loan = state.loans[params.loanId];

        state.f.borrowToken.transferFrom(state.g.variablePool, loan.lender, loan.getCredit());
        loan.faceValueExited = loan.faceValue;

        emit Events.Claim(params.loanId);
    }
}
