// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

import {Loan} from "@src/libraries/fixed/LoanLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct SelfLiquidateLoanParams {
    uint256 loanId;
}

library SelfLiquidateLoan {
    using LoanLibrary for Loan;
    using LoanLibrary for State;
    using VariableLibrary for State;
    using AccountingLibrary for State;
    using RiskLibrary for State;

    function validateSelfLiquidateLoan(State storage state, SelfLiquidateLoanParams calldata params) external view {
        Loan storage loan = state.data.loans[params.loanId];
        Loan storage fol = state.getFOL(loan);

        uint256 assignedCollateral = state.getProRataAssignedCollateral(params.loanId);
        uint256 debtWad = ConversionLibrary.amountToWad(fol.getDebt(), state.data.underlyingBorrowToken.decimals());
        uint256 debtCollateral =
            Math.mulDivDown(debtWad, 10 ** state.oracle.priceFeed.decimals(), state.oracle.priceFeed.getPrice());

        // validate msg.sender
        if (msg.sender != loan.generic.lender) {
            revert Errors.LIQUIDATOR_IS_NOT_LENDER(msg.sender, loan.generic.lender);
        }

        // validate loanId
        if (!state.isLoanSelfLiquidatable(params.loanId)) {
            revert Errors.LOAN_NOT_SELF_LIQUIDATABLE(
                params.loanId, state.collateralRatio(loan.generic.borrower), state.getLoanStatus(loan)
            );
        }
        if (!(assignedCollateral < debtCollateral)) {
            revert Errors.LIQUIDATION_NOT_AT_LOSS(params.loanId, assignedCollateral, debtCollateral);
        }
    }

    function executeSelfLiquidateLoan(State storage state, SelfLiquidateLoanParams calldata params) external {
        emit Events.SelfLiquidateLoan(params.loanId);

        Loan storage loan = state.data.loans[params.loanId];
        Loan storage fol = state.getFOL(loan);

        uint256 credit = loan.generic.credit;

        uint256 assignedCollateral = state.getProRataAssignedCollateral(params.loanId);
        state.data.collateralToken.transferFrom(fol.generic.borrower, msg.sender, assignedCollateral);

        state.reduceLoanCredit(params.loanId, credit);
        state.chargeRepayFee(fol, credit);
        state.data.debtToken.burn(fol.generic.borrower, credit);
    }
}
