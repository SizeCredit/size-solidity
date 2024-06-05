// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/core/SizeStorage.sol";

import {AccountingLibrary} from "@src/core/libraries/fixed/AccountingLibrary.sol";
import {RiskLibrary} from "@src/core/libraries/fixed/RiskLibrary.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/core/libraries/fixed/LoanLibrary.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";

struct RepayParams {
    uint256 debtPositionId;
}

/// @title Repay
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library Repay {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    function validateRepay(State storage state, RepayParams calldata params) external view {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionId);
        }

        // validate msg.sender
        if (state.data.borrowAToken.balanceOf(msg.sender) < debtPosition.futureValue) {
            revert Errors.NOT_ENOUGH_BORROW_ATOKEN_BALANCE(
                msg.sender, state.data.borrowAToken.balanceOf(msg.sender), debtPosition.futureValue
            );
        }
    }

    function executeRepay(State storage state, RepayParams calldata params) external {
        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);
        uint256 futureValue = debtPosition.futureValue;

        state.data.borrowAToken.transferFrom(msg.sender, address(this), futureValue);
        state.repayDebt(params.debtPositionId, futureValue);

        emit Events.Repay(params.debtPositionId);
    }
}
