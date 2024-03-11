// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Math} from "@src/libraries/Math.sol";
import {CreditPosition, DebtPosition, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct ClaimParams {
    uint256 creditPositionId;
}

library Claim {
    using VariableLibrary for State;
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
            creditPosition.credit, state.borrowATokenLiquidityIndex(), debtPosition.liquidityIndexAtRepayment
        );
        state.transferBorrowAToken(address(this), creditPosition.lender, claimAmount);
        creditPosition.credit = 0;

        emit Events.Claim(params.creditPositionId);
    }
}
