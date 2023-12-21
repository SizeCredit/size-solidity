// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {Loan} from "@src/libraries/LoanLibrary.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {LiquidateLoan} from "@src/libraries/actions/LiquidateLoan.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateLoanParams {
    uint256 loanId;
}

library SelfLiquidateLoan {
    using LoanLibrary for Loan;

    function validateSelfLiquidateLoan(State storage state, SelfLiquidateLoanParams calldata params) external view {
        Loan memory loan = state.loans[params.loanId];
        uint256 assignedCollateral = LiquidateLoan.getAssignedCollateral(state, loan);
        uint256 debtCollateral =
            FixedPointMathLib.mulDivDown(loan.getDebt(), 10 ** state.priceFeed.decimals(), state.priceFeed.getPrice());

        // validate msg.sender
        if (msg.sender != loan.borrower) {
            revert Errors.LIQUIDATOR_IS_NOT_BORROWER(msg.sender, loan.borrower);
        }

        // validate loanId
        // @audit is this necessary? seems redundant with the check `assignedCollateral > debtCollateral` below,
        //   as CR < CRL ==> CR <= 100%
        if (!LiquidateLoan.isLiquidatable(state, loan.borrower)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_CR(params.loanId, LiquidateLoan.collateralRatio(state, loan.borrower));
        }
        // @audit is this reachable?
        if (!loan.either([LoanStatus.ACTIVE, LoanStatus.OVERDUE])) {
            revert Errors.LOAN_NOT_LIQUIDATABLE_STATUS(params.loanId, loan.getLoanStatus());
        }
        if (assignedCollateral > debtCollateral) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.loanId);
        }
    }

    function executeSelfLiquidateLoan(State storage state, SelfLiquidateLoanParams calldata params) external {
        emit Events.SelfLiquidateLoan(params.loanId);

        Loan storage loan = state.loans[params.loanId];

        uint256 assignedCollateral = LiquidateLoan.getAssignedCollateral(state, loan);
        state.collateralToken.transferFrom(msg.sender, loan.lender, assignedCollateral);

        uint256 deltaFV = loan.getCredit();
        loan.faceValue -= deltaFV;

        Loan storage fol = loan.getFOL(state.loans);
        state.debtToken.burn(fol.borrower, deltaFV);

        if (!loan.isFOL()) {
            fol.faceValue -= deltaFV;
            fol.faceValueExited -= deltaFV;
        }
    }
}
