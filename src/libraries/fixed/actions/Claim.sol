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
        // validate msg.sender

        // validate creditPositionId
        if (!state.isCreditPositionId(params.creditPositionId)) {
            revert Errors.ONLY_CREDIT_POSITION_CAN_BE_CLAIMED(params.creditPositionId);
        }
        if (state.getLoanStatus(params.creditPositionId) != LoanStatus.REPAID) {
            revert Errors.LOAN_NOT_REPAID(params.creditPositionId);
        }
    }

    function executeClaim(State storage state, ClaimParams calldata params) external {
        CreditPosition storage creditPosition = state.data.creditPositions[params.creditPositionId];
        DebtPosition storage debtPosition = state.getDebtPosition(params.creditPositionId);

        uint256 claimAmount = Math.mulDivDown(
            creditPosition.credit, state.borrowATokenLiquidityIndex(), debtPosition.liquidityIndexAtRepayment
        );
        state.transferBorrowAToken(address(this), creditPosition.lender, claimAmount);
        creditPosition.credit = 0;

        emit Events.Claim(params.creditPositionId);
    }
}
