// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedLoan} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 loanId;
}

library Claim {
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender
        // @audit Check if this should be permissioned

        // validate loanId
        if (state.getFixedLoanStatus(loan) != FixedLoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.loanId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        state._fixed.borrowToken.transferFrom(state._general.variablePool, loan.lender, loan.getCredit());
        loan.faceValueExited = loan.faceValue;

        emit Events.Claim(params.loanId);
    }
}