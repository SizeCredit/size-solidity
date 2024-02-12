// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 debtPositionId;
}

library Repay {
    using VariableLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using AccountingLibrary for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        DebtPosition storage debtPosition = state.data.debtPositions[params.debtPositionId];

        // validate msg.sender
        if (msg.sender != debtPosition.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, debtPosition.borrower);
        }
        if (state.borrowATokenBalanceOf(msg.sender) < debtPosition.faceValue()) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(
                state.borrowATokenBalanceOf(msg.sender), debtPosition.faceValue()
            );
        }

        // validate debtPositionId
        if (!state.isDebtPositionId(params.debtPositionId)) {
            revert Errors.ONLY_DEBT_POSITION_CAN_BE_REPAID(params.debtPositionId);
        }
        if (state.getLoanStatus(params.debtPositionId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionId);
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        DebtPosition storage debtPosition = state.data.debtPositions[params.debtPositionId];
        uint256 faceValue = debtPosition.faceValue();

        state.transferBorrowAToken(msg.sender, address(this), faceValue);
        state.chargeRepayFee(debtPosition, faceValue);
        state.data.debtToken.burn(debtPosition.borrower, faceValue);
        debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();

        emit Events.Repay(params.debtPositionId);
    }
}
