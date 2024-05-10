// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {VariablePoolLibrary} from "@src/libraries/variable/VariablePoolLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 debtPositionId;
}

library Repay {
    using VariablePoolLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using AccountingLibrary for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionId);
        }

        // validate msg.sender
        if (state.borrowATokenBalanceOf(msg.sender) < debtPosition.faceValue) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(
                msg.sender, state.borrowATokenBalanceOf(msg.sender), debtPosition.faceValue
            );
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        uint256 faceValue = debtPosition.faceValue;

        state.transferBorrowAToken(msg.sender, address(this), faceValue);
        state.repayDebt(params.debtPositionId, faceValue, true, true);

        emit Events.Repay(params.debtPositionId);
    }
}
