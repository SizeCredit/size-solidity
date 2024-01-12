// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {FixedLoan, FixedLoanLibrary, VariableFixedLoan} from "@src/libraries/FixedLoanLibrary.sol";
import {Common} from "@src/libraries/actions/Common.sol";

import {FixedLoanStatus} from "@src/libraries/FixedLoanLibrary.sol";

struct MoveToVariablePoolParams {
    uint256 loanId;
}

library MoveToVariablePool {
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for VariableFixedLoan;
    using FixedLoanLibrary for VariableFixedLoan[];
    using Common for State;

    function validateMoveToVariablePool(State storage state, MoveToVariablePoolParams calldata params) external view {
        FixedLoan storage loan = state.loans[params.loanId];

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

        FixedLoan storage loan = state.loans[params.loanId];

        // In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed
        uint256 assignedCollateral = state.getFOLAssignedCollateral(loan);
        uint256 minimumCollateralOpening = state.getMinimumCollateralOpening(loan.faceValue);

        if (assignedCollateral < minimumCollateralOpening) {
            revert Errors.INSUFFICIENT_COLLATERAL(assignedCollateral, minimumCollateralOpening);
        }

        state.f.collateralToken.transferFrom(loan.borrower, state.g.variablePool, assignedCollateral);
        loan.repaid = true;
        state.createVariableFixedLoan({
            borrower: loan.borrower,
            amountBorrowAssetLentOut: loan.faceValue,
            amountCollateral: assignedCollateral
        });
    }
}
