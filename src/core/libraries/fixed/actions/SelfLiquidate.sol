// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {AccountingLibrary} from "@src/core/libraries/fixed/AccountingLibrary.sol";

import {PERCENT} from "@src/core/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary} from "@src/core/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/core/libraries/fixed/RiskLibrary.sol";

import {State} from "@src/core/SizeStorage.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";

struct SelfLiquidateParams {
    uint256 creditPositionId;
}

/// @title SelfLiquidate
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
library SelfLiquidate {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    function validateSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        // validate creditPositionId
        if (!state.isCreditPositionSelfLiquidatable(params.creditPositionId)) {
            revert Errors.LOAN_NOT_SELF_LIQUIDATABLE(
                params.creditPositionId,
                state.collateralRatio(debtPosition.borrower),
                state.getLoanStatus(params.creditPositionId)
            );
        }
        if (state.collateralRatio(debtPosition.borrower) >= PERCENT) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.creditPositionId, state.collateralRatio(debtPosition.borrower));
        }

        // validate msg.sender
        if (msg.sender != creditPosition.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(msg.sender, creditPosition.lender);
        }
    }

    function executeSelfLiquidate(State storage state, SelfLiquidateParams calldata params) external {
        emit Events.SelfLiquidate(params.creditPositionId);

        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 assignedCollateral = state.getCreditPositionProRataAssignedCollateral(creditPosition);

        state.repayDebt(creditPosition.debtPositionId, creditPosition.credit, false);

        // slither-disable-next-line unused-return
        state.reduceCredit(params.creditPositionId, creditPosition.credit);

        state.data.collateralToken.transferFrom(debtPosition.borrower, msg.sender, assignedCollateral);
    }
}
