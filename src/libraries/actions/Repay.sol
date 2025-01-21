// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/libraries/RiskLibrary.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct RepayParams {
    uint256 debtPositionId;
    address borrower;
}

/// @title Repay
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for repaying a debt position
///         This method can only repay in full. For partial repayments, check Compensate
/// @dev Anyone can repay a debt position
library Repay {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    /// @notice Validates the input parameters for repaying a debt position
    /// @param state The state
    /// @param params The input parameters for repaying a debt position
    function validateRepay(State storage state, RepayParams calldata params) external view {
        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionId);
        }

        // validate borrower
        if (state.getDebtPosition(params.debtPositionId).borrower != params.borrower) {
            revert Errors.INVALID_BORROWER(params.borrower);
        }

        // validate msg.sender
        // N/A
    }

    /// @notice Executes the repayment of a debt position
    /// @param state The state
    /// @param params The input parameters for repaying a debt position
    function executeRepay(State storage state, RepayParams calldata params) external {
        emit Events.Repay(msg.sender, params.debtPositionId, params.borrower);

        DebtPosition storage debtPosition = state.getDebtPosition(params.debtPositionId);

        state.data.borrowATokenV1_5.transferFrom(msg.sender, address(this), debtPosition.futureValue);
        debtPosition.liquidityIndexAtRepayment = state.data.borrowATokenV1_5.liquidityIndex();
        state.repayDebt(params.debtPositionId, debtPosition.futureValue);
    }
}
