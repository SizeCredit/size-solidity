// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BeforeAfter} from "./BeforeAfter.sol";
import {Asserts} from "@chimera/Asserts.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

abstract contract Properties is BeforeAfter, Asserts {
    string internal constant DEPOSIT_01 = "DEPOSIT_01: Deposit must credit the sender in wad";
    string internal constant WITHDRAW_01 = "WITHDRAW_01: Withdraw must deduct from the sender in wad";

    string internal constant LOAN_01 = "LOAN_01: loan.faceValue <= FOL(loan).faceValue";
    string internal constant LOAN_02 = "LOAN_02: SUM(loan.credit) foreach loan in FOL.loans = FOL(loan).faceValue";
    string internal constant LOAN_03 = "LOAN_03: loan.faceValueExited <= loan.faceValue";
    string internal constant LOAN_04 = "LOAN_04: loan.repaid => !loan.isFOL()";

    string internal constant LIQUIDATION_01 =
        "LIQUIDATION_01: A user cannot make an operation that leaves them liquidatable";

    function invariant_LOAN() public returns (bool) {
        uint256 activeLoans = size.activeLoans();
        uint256[] memory credits = new uint256[](activeLoans);
        uint256[] memory faceValues = new uint256[](activeLoans);
        for (uint256 loanId; loanId < activeLoans; loanId++) {
            Loan memory loan = size.getLoan(loanId);
            if (size.isFOL(loanId)) {
                if (loan.repaid) {
                    t(false, LOAN_04);
                    return false;
                }
            } else {
                Loan memory fol = size.getLoan(loan.folId);
                credits[loan.folId] = size.getCredit(loanId);
                faceValues[loan.folId] = fol.faceValue;

                if (!(loan.faceValue <= fol.faceValue)) {
                    t(false, LOAN_01);
                    return false;
                }
            }

            if (!(loan.faceValueExited <= loan.faceValue)) {
                t(false, LOAN_03);
                return false;
            }
        }

        for (uint256 loanId; loanId < activeLoans; loanId++) {
            if (credits[loanId] != faceValues[loanId]) {
                t(false, LOAN_02);
                return false;
            }
        }
        return true;
    }

    function invariant_LIQUIDATION_01() public returns (bool) {
        if (!_before.isLiquidatable && _after.isLiquidatable) {
            t(false, LIQUIDATION_01);
            return false;
        }
        return true;
    }
}
