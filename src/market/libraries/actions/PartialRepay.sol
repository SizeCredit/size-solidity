// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {State} from "@src/market/SizeStorage.sol";

import {Math} from "@src/market/libraries/Math.sol";

import {AccountingLibrary} from "@src/market/libraries/AccountingLibrary.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {Events} from "@src/market/libraries/Events.sol";
import {
    CreditPosition, DebtPosition, LoanLibrary, LoanStatus, RESERVED_ID
} from "@src/market/libraries/LoanLibrary.sol";

import {Action} from "@src/factory/libraries/Authorization.sol";
import {RiskLibrary} from "@src/market/libraries/RiskLibrary.sol";

struct PartialRepayParams {
    // The credit position ID with debt to repay
    uint256 creditPositionWithDebtToRepayId;
    // The amount to repay
    uint256 amount;
    // The borrower of the debt position
    address borrower;
}

/// @title PartialRepay
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice Contains the logic for partial repaying a debt position by selecting a specific CreditPosition
/// @dev Anyone can repay a debt position
library PartialRepay {
    using AccountingLibrary for State;
    using LoanLibrary for State;
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;

    using RiskLibrary for State;

    /// @notice Validates the input parameters for partial repaying a debt position by selecting a specific CreditPosition
    /// @param state The state of the protocol
    /// @param params The input parameters for partial repaying a debt position by selecting a specific CreditPosition
    function validatePartialRepay(State storage state, PartialRepayParams memory params) external view {
        CreditPosition storage creditPositionWithDebtToRepay =
            state.getCreditPosition(params.creditPositionWithDebtToRepayId);
        DebtPosition storage debtPositionToRepay = state.getDebtPosition(creditPositionWithDebtToRepay.debtPositionId);

        // validate msg.sender
        // N/A

        // validate creditPositionWithDebtToRepayId
        if (state.getLoanStatus(params.creditPositionWithDebtToRepayId) == LoanStatus.REPAID) {
            revert Errors.LOAN_ALREADY_REPAID(params.creditPositionWithDebtToRepayId);
        }

        // validate amount
        if (params.amount == 0) {
            revert Errors.NULL_AMOUNT();
        }
        if (
            params.amount >= debtPositionToRepay.futureValue || params.amount > creditPositionWithDebtToRepay.credit
                || params.amount < state.riskConfig.minimumCreditBorrowAToken
        ) {
            // disallows partial repayments of
            // - the entire debt
            // - more than the credit position
            // - less than the minimumCreditBorrowAToken amount
            revert Errors.INVALID_AMOUNT(params.amount);
        }

        // validate borrower
        if (debtPositionToRepay.borrower != params.borrower) {
            revert Errors.INVALID_BORROWER(params.borrower);
        }
    }

    /// @notice Executes the partial repayment of a debt position by selecting a specific CreditPosition
    /// @param state The state of the protocol
    /// @param params The input parameters for partial repaying a debt position by selecting a specific CreditPosition
    function executePartialRepay(State storage state, PartialRepayParams memory params) external {
        emit Events.PartialRepay(msg.sender, params.creditPositionWithDebtToRepayId, params.amount, params.borrower);

        CreditPosition storage creditPositionWithDebtToRepay =
            state.getCreditPosition(params.creditPositionWithDebtToRepayId);

        // transfer cash directly to the lender since it's a partial repayment
        state.data.borrowATokenV1_5.transferFrom(msg.sender, creditPositionWithDebtToRepay.lender, params.amount);
        // debt and credit reduction
        state.reduceDebtAndCredit(
            creditPositionWithDebtToRepay.debtPositionId, params.creditPositionWithDebtToRepayId, params.amount
        );
    }
}
