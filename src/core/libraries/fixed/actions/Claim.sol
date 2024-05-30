// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math} from "@src/core/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/core/libraries/fixed/LoanLibrary.sol";

import {State} from "@src/core/SizeStorage.sol";

import {AccountingLibrary} from "@src/core/libraries/fixed/AccountingLibrary.sol";

import {Errors} from "@src/core/libraries/Errors.sol";
import {Events} from "@src/core/libraries/Events.sol";

struct ClaimParams {
    uint256 creditPositionId;
}

library Claim {
    using LoanLibrary for CreditPosition;
    using LoanLibrary for State;
    using AccountingLibrary for State;

    function validateClaim(State storage state, ClaimParams calldata params) external view {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        // validate msg.sender
        // N/A

        // validate creditPositionId
        if (state.getLoanStatus(params.creditPositionId) != LoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.creditPositionId);
        }
        if (creditPosition.credit == 0) {
            revert Errors.CREDIT_POSITION_ALREADY_CLAIMED(params.creditPositionId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        CreditPosition storage creditPosition = state.getCreditPosition(params.creditPositionId);
        DebtPosition storage debtPosition = state.getDebtPositionByCreditPositionId(params.creditPositionId);

        uint256 claimAmount = Math.mulDivDown(
            creditPosition.credit, state.data.borrowAToken.liquidityIndex(), debtPosition.liquidityIndexAtRepayment
        );
        // slither-disable-next-line unused-return
        state.reduceCredit(params.creditPositionId, creditPosition.credit);
        state.data.borrowAToken.transferFrom(address(this), creditPosition.lender, claimAmount);

        emit Events.Claim(params.creditPositionId, creditPosition.debtPositionId);
    }
}
