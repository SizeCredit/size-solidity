// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";
import {VariableLibrary} from "@src/libraries/variable/VariableLibrary.sol";

import {FixedLoan, FixedLoanLibrary, RESERVED_ID} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

library AccountingLibrary {
    using RiskLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;
    using VariableLibrary for State;

    function transferCredit(State storage state, uint256 loanIdFrom, uint256 loanIdTo, uint256 amount) public {
        FixedLoan storage loanFrom = state._fixed.loans[loanIdFrom];
        FixedLoan storage loanTo = state._fixed.loans[loanIdTo];

        loanFrom.credit -= amount;
        loanTo.credit += amount;

        state.validateMinimumCredit(loanFrom.credit);
    }

    function transferDebt(State storage state, address borrowerFrom, address borrowerTo, uint256 amount) public {
        // TODO transfer repay fee

        state._fixed.debtToken.transferFrom(borrowerFrom, borrowerTo, amount);
    }

    function reduceCredit(State storage state, uint256 loanId, uint256 amount) public {
        FixedLoan storage loan = state._fixed.loans[loanId];
        loan.credit -= amount;

        state.validateMinimumCredit(loan.credit);
    }

    function reduceDebt(State storage state, uint256 loanId, uint256 amount) public {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoan storage fol = state.getFOL(loan);

        // uint256 repayFee = state.currentRepayFee(loan, repayAmount);
        // uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, state._general.borrowAsset.decimals());
        // uint256 repayFeeCollateral =
        //     Math.mulDivUp(repayFeeWad, 10 ** state._general.priceFeed.decimals(), state._general.priceFeed.getPrice());
        // state._fixed.collateralToken.transferFrom(msg.sender, state._general.feeRecipient, repayFeeCollateral);

        // TODO also burn repayFee
        state._fixed.debtToken.burn(fol.borrower, amount);

        loan.debt -= amount;

        if (!loan.isFOL()) {
            fol.debt -= amount;
        }

        if (fol.debt == 0) {
            loan.liquidityIndexAtRepayment = state.borrowATokenLiquidityIndex();
        }
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(
        State storage state,
        address lender,
        address borrower,
        uint256 issuanceValue,
        uint256 faceValue,
        uint256 dueDate
    ) public returns (FixedLoan memory fol) {
        fol = FixedLoan({
            issuanceValue: issuanceValue,
            faceValue: faceValue,
            credit: faceValue,
            debt: faceValue,
            lender: lender,
            borrower: borrower,
            startDate: block.timestamp,
            dueDate: dueDate,
            liquidityIndexAtRepayment: 0,
            folId: RESERVED_ID
        });
        state.validateMinimumCreditOpening(fol.credit);

        state._fixed.loans.push(fol);
        uint256 folId = state._fixed.loans.length - 1;

        emit Events.CreateFixedLoan(
            folId, lender, borrower, RESERVED_ID, RESERVED_ID, issuanceValue, faceValue, dueDate
        );
    }

    // solhint-disable-next-line var-name-mixedcase
    function createSOL(
        State storage state,
        uint256 exiterId,
        address lender,
        address borrower,
        uint256 issuanceValue,
        uint256 faceValue
    ) public returns (FixedLoan memory sol) {
        uint256 folId = state.getFOLId(exiterId);
        FixedLoan storage fol = state._fixed.loans[folId];

        sol = FixedLoan({
            issuanceValue: issuanceValue,
            faceValue: faceValue,
            credit: 0,
            debt: faceValue,
            lender: lender,
            borrower: borrower,
            startDate: block.timestamp,
            dueDate: fol.dueDate,
            liquidityIndexAtRepayment: 0,
            folId: folId
        });

        state._fixed.loans.push(sol);
        uint256 solId = state._fixed.loans.length - 1;

        transferCredit(state, exiterId, solId, faceValue);
        state.validateMinimumCreditOpening(faceValue);

        emit Events.CreateFixedLoan(solId, lender, borrower, exiterId, folId, issuanceValue, faceValue, fol.dueDate);
    }
}
