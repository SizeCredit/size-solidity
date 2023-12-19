// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 loanId;
}

library Claim {
    using LoanLibrary for Loan;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        Loan memory loan = state.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.lender) {
            revert Errors.CLAIMER_IS_NOT_LENDER(msg.sender, loan.lender);
        }

        // validate loanId
        // NOTE: Both ACTIVE and OVERDUE loans can't be claimed because the money is not in the protocol yet
        // NOTE: The CLAIMED can't be claimed either because its credit has already been consumed entirely
        //    either by a previous claim or by exiting before
        if (loan.getLoanStatus() != LoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.loanId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        Loan storage loan = state.loans[params.loanId];

        // @audit amountFVExited can increase if SOLs are created, what if claim/exit happen in different times?
        state.borrowToken.transferFrom(state.protocolVault, msg.sender, loan.getCredit());
        loan.amountFVExited = loan.FV;

        emit Events.Claim(params.loanId);
    }
}
