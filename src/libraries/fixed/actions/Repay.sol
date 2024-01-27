// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {Math} from "@src/libraries/Math.sol";
import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";

import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
}

library Repay {
    using VariableLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, loan.borrower);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < loan.faceValue) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowATokenBalanceOf(msg.sender), loan.faceValue);
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
            state.transferBorrowAToken(msg.sender, address(this), repayAmount);
            state._fixed.debtToken.burn(msg.sender, repayAmount);
            loan.repaid = true;
        } else {
            state.transferBorrowAToken(msg.sender, loan.lender, repayAmount);
            state.reduceDebt(params.loanId, repayAmount);
        }

        emit Events.Repay(params.loanId, repayAmount);
    }
}
