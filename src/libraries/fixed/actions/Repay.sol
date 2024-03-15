// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

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
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionId);
        }

        // validate msg.sender
        if (msg.sender != debtPosition.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(msg.sender, debtPosition.borrower);
        }
        if (state.aTokenBalanceOf(state.data.borrowAToken, msg.sender, false) < debtPosition.faceValue) {
            revert Errors.NOT_ENOUGH_ATOKEN_BALANCE(
                address(state.data.borrowAToken),
                msg.sender,
                false,
                state.aTokenBalanceOf(state.data.borrowAToken, msg.sender, false),
                debtPosition.faceValue
            );
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        uint256 faceValue = debtPosition.faceValue;

        state.transferBorrowATokenFixed(msg.sender, address(this), faceValue);
        state.chargeRepayFeeInCollateral(debtPosition, faceValue);
        state.updateRepayFee(debtPosition, faceValue);
        state.data.debtToken.burn(debtPosition.borrower, faceValue);
        debtPosition.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();

        emit Events.Repay(params.debtPositionId);
    }
}
