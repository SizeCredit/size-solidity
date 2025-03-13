// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/market/SizeStorage.sol";

import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

import {DebtPosition, LoanLibrary, LoanStatus} from "@src/market/libraries/LoanLibrary.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";

struct RepayParams {
    // The debt position ID to repay
    uint256 debtPositionId;
    // The borrower of the debt position
    address borrower;
}

/// @title Repay
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for repaying a debt position
///         This method can only repay in full. For partial repayments, check PartialRepay
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
        // validate msg.sender
        // N/A

        // validate debtPositionId
        if (state.getLoanStatus(params.debtPositionId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.debtPositionId);
        }

        // validate borrower
        if (state.getDebtPosition(params.debtPositionId).borrower != params.borrower) {
            revert Errors.INVALID_BORROWER(params.borrower);
        }
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
