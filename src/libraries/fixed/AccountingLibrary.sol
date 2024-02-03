// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {Events} from "@src/libraries/Events.sol";

import {Math} from "@src/libraries/Math.sol";
import {FixedLoan, FixedLoanLibrary, RESERVED_ID} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {RiskLibrary} from "@src/libraries/fixed/RiskLibrary.sol";

library AccountingLibrary {
    using RiskLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for State;

    function reduceDebt(State storage state, uint256 loanId, uint256 amount) public {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoan storage fol = state.getFOL(loan);

        state._fixed.debtToken.burn(fol.borrower, amount);

        loan.issuanceValue -= Math.max(Math.mulDivUp(amount, loan.issuanceValue, loan.faceValue), loan.issuanceValue);
        loan.faceValue -= amount;
        state.validateMinimumCredit(loan.getCredit());

        if (!loan.isFOL()) {
            fol.issuanceValue -= Math.max(Math.mulDivUp(amount, fol.issuanceValue, fol.faceValue), fol.issuanceValue);
            fol.faceValue -= amount;
            fol.faceValueExited -= amount;
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
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            startDate: block.timestamp,
            dueDate: dueDate,
            repaid: false,
            liquidityIndexAtRepayment: 0,
            folId: RESERVED_ID
        });
        state.validateMinimumCreditOpening(fol.getCredit());

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
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            startDate: block.timestamp,
            dueDate: fol.dueDate,
            repaid: false,
            liquidityIndexAtRepayment: 0,
            folId: folId
        });

        state.validateMinimumCreditOpening(sol.getCredit());
        state._fixed.loans.push(sol);
        uint256 solId = state._fixed.loans.length - 1;

        FixedLoan storage exiter = state._fixed.loans[exiterId];
        exiter.faceValueExited += faceValue;
        state.validateMinimumCredit(exiter.getCredit());

        emit Events.CreateFixedLoan(solId, lender, borrower, exiterId, folId, issuanceValue, faceValue, fol.dueDate);
    }
}
