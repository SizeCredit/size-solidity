// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
}

library Repay {
    using VariableLibrary for State;
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using AccountingLibrary for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        Loan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.generic.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, loan.generic.borrower);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < loan.faceValue()) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(state.borrowATokenBalanceOf(msg.sender), loan.faceValue());
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
        Loan storage fol = state._fixed.loans[params.loanId];
        uint256 faceValue = fol.faceValue();

        state.transferBorrowAToken(msg.sender, address(this), faceValue);
        state.chargeRepayFee(fol, faceValue);
        state._fixed.debtToken.burn(fol.generic.borrower, faceValue);
        fol.fol.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();

        emit Events.Repay(params.loanId);
    }
}
