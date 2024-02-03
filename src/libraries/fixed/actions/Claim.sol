// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Math} from "@src/libraries/Math.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 loanId;
}

library Claim {
    using VariableLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender

        // validate loanId
        if (state.getFixedLoanStatus(loan) != FixedLoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.loanId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        FixedLoan storage loan = state._fixed.loans[params.loanId];
        FixedLoan storage fol = state.getFOL(loan);

        uint256 claimAmount =
            Math.mulDivDown(loan.getCredit(), state.borrowATokenLiquidityIndex(), fol.liquidityIndexAtRepayment);
        state.transferBorrowAToken(address(this), loan.lender, claimAmount);
        loan.faceValueExited = loan.faceValue;

        emit Events.Claim(params.loanId);
    }
}
