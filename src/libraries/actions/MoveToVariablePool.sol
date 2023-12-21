// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Loan, LoanLibrary, VariableLoan} from "@src/libraries/LoanLibrary.sol";

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {BorrowAsMarketOrder} from "@src/libraries/actions/BorrowAsMarketOrder.sol";
import {LiquidateLoan} from "@src/libraries/actions/LiquidateLoan.sol";

struct MoveToVariablePoolParams {
    uint256 loanId;
}

library MoveToVariablePool {
    using LoanLibrary for Loan;
    using LoanLibrary for VariableLoan;
    using LoanLibrary for VariableLoan[];

    function validateMoveToVariablePool(State storage state, MoveToVariablePoolParams calldata params) external view {
        Loan memory loan = state.loans[params.loanId];

        // validate msg.sender

        // validate params.loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_MOVED_TO_VP(params.loanId);
        }
        if (loan.getLoanStatus() != LoanStatus.OVERDUE) {
            revert Errors.INVALID_LOAN_STATUS(params.loanId, loan.getLoanStatus(), LoanStatus.OVERDUE);
        }
    }

    function executeMoveToVariablePool(State storage state, MoveToVariablePoolParams calldata params) external {
        Loan storage loan = state.loans[params.loanId];

        // In moving the loan from the fixed term to the variable, we assign collateral once to the loan and it is fixed
        uint256 assignedCollateral = LiquidateLoan.getAssignedCollateral(state, loan);
        uint256 minimumCollateralOpening = BorrowAsMarketOrder.getMinimumCollateralOpening(state, loan.faceValue);

        if (assignedCollateral < minimumCollateralOpening) {
            revert Errors.INSUFFICIENT_COLLATERAL(assignedCollateral, minimumCollateralOpening);
        }

        state.collateralToken.transferFrom(loan.borrower, state.protocolVault, assignedCollateral);
        loan.repaid = true;
        state.variableLoans.createVariableLoan(loan.borrower, loan.faceValue, assignedCollateral);
    }
}