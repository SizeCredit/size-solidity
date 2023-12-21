// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {Common} from "@src/libraries/actions/Common.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateLoanParams {
    uint256 loanId;
}

library SelfLiquidateLoan {
    using LoanLibrary for Loan;
    using Common for State;

    function validateSelfLiquidateLoan(State storage state, SelfLiquidateLoanParams calldata params) external view {
        Loan memory loan = state.loans[params.loanId];
        uint256 assignedCollateral = state.getAssignedCollateral(loan);
        uint256 debtCollateral =
            FixedPointMathLib.mulDivDown(loan.getDebt(), 10 ** state.priceFeed.decimals(), state.priceFeed.getPrice());

        // validate msg.sender
        if (msg.sender != loan.borrower) {
            revert Errors.LIQUIDATOR_IS_NOT_BORROWER(msg.sender, loan.borrower);
        }

        // validate loanId
        // @audit is this necessary? seems redundant with the check `assignedCollateral > debtCollateral` below,
        //   as CR < CRL ==> CR <= 100%
        if (!state.isLiquidatable(loan.borrower)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_CR(params.loanId, state.collateralRatio(loan.borrower));
        }
        // @audit is this reachable?
        if (!state.either(loan, [LoanStatus.ACTIVE, LoanStatus.OVERDUE])) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_STATUS(params.loanId, state.getLoanStatus(loan));
        }
        if (assignedCollateral > debtCollateral) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.loanId, assignedCollateral, debtCollateral);
        }
    }

    function executeSelfLiquidateLoan(State storage state, SelfLiquidateLoanParams calldata params) external {
        emit Events.SelfLiquidateLoan(params.loanId);

        Loan storage loan = state.loans[params.loanId];

        uint256 assignedCollateral = state.getAssignedCollateral(loan);
        state.collateralToken.transferFrom(msg.sender, loan.lender, assignedCollateral);

        uint256 credit = loan.getCredit();
        Loan storage fol = state.getFOL(loan);
        state.debtToken.burn(fol.borrower, credit);

        if (loan.isFOL()) {
            // loan.faceValue = loan.faceValue - (loan.faceValue - loan.faceValueExited) = loan.faceValueExited
            // since sol.faceValueExited == 0 (no exits) or loan.faceValueExited >= state.minimumFaceValue always (by construction, see createSOL)
            // we don't need to call state.validateMinimumFaceValueFOL(loan.faceValue);
            loan.faceValue -= credit;
        } else {
            loan.faceValue -= credit; // loan.faceValue will be 0

            fol.faceValue -= credit;
            fol.faceValueExited -= credit;
            if (fol.faceValue > 0) {
                state.validateMinimumFaceValueSOL(fol.faceValue);
            }
        }
    }
}
