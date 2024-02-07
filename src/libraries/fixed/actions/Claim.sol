// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 loanId;
}

library Claim {
    using VariableLibrary for State;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using AccountingLibrary for State;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        Loan storage loan = state.data.loans[params.loanId];

        // validate msg.sender

        // validate loanId
        if (state.getLoanStatus(loan) != LoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.loanId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        Loan storage loan = state.data.loans[params.loanId];
        Loan storage fol = state.getFOL(loan);

        uint256 claimAmount =
            Math.mulDivDown(loan.generic.credit, state.borrowATokenLiquidityIndex(), fol.fol.liquidityIndexAtRepayment);
        state.transferBorrowAToken(address(this), loan.generic.lender, claimAmount);
        state.reduceLoanCredit(params.loanId, loan.generic.credit);

        emit Events.Claim(params.loanId);
    }
}
