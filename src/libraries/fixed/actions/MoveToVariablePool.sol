// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

import {FixedLibrary} from "@src/libraries/fixed/FixedLibrary.sol";
import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

struct MoveToVariablePoolParams {
    uint256 loanId;
}

library MoveToVariablePool {
    using FixedLoanLibrary for FixedLoan;
    using FixedLibrary for State;
    using VariableLibrary for State;

    function validateMoveToVariablePool(State storage state, MoveToVariablePoolParams calldata params) external view {
        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // validate msg.sender

        // validate params.loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_MOVED_TO_VP(params.loanId);
        }
        if (state.getFixedLoanStatus(loan) != FixedLoanStatus.OVERDUE) {
            revert Errors.INVALID_LOAN_STATUS(params.loanId, state.getFixedLoanStatus(loan), FixedLoanStatus.OVERDUE);
        }
    }

    function executeMoveToVariablePool(State storage state, MoveToVariablePoolParams calldata params) external {
        emit Events.MoveToVariablePool(params.loanId);

        FixedLoan storage loan = state._fixed.loans[params.loanId];

        // In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed
        uint256 assignedCollateral = state.getFOLAssignedCollateral(loan);

        state.borrowFromVariablePool(loan.borrower, address(this), assignedCollateral, loan.faceValue);
        // @audit Check if the liquidity index snapshot should happen before or after Aave borrow
        loan.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        loan.repaid = true;
    }
}
