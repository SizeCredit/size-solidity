// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {FeeLibrary} from "@src/libraries/fixed/FeeLibrary.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 loanId;
}

library Repay {
    using VariableLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;
    using AccountingLibrary for State;
    using AccountingLibrary for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender
        if (msg.sender != loan.generic.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, loan.generic.borrower);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < loan.faceValue()) {
            revert Errors.NOT_ENOUGH_FREE_CASH(state.borrowATokenBalanceOf(msg.sender), loan.faceValue());
        }

        // validate loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_REPAID(params.loanId);
        }
        if (state.either(loan, [FixedLoanStatus.REPAID, FixedLoanStatus.CLAIMED])) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanId);
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        FixedLoan storage fol = state._fixed.loans[params.loanId];
        uint256 faceValue = fol.faceValue();

        state.transferBorrowAToken(msg.sender, address(this), faceValue);
        state.chargeRepayFee(fol, faceValue);
        state._fixed.debtToken.burn(fol.generic.borrower, faceValue);
        fol.fol.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();

        emit Events.Repay(params.loanId);
    }
}
