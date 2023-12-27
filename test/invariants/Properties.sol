// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BeforeAfter} from "./BeforeAfter.sol";
import {Asserts} from "@chimera/Asserts.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";

abstract contract Properties is BeforeAfter, Asserts {
    string internal constant DEPOSIT_01 = "DEPOSIT_01: Deposit must credit the sender in wad";
    string internal constant WITHDRAW_01 = "WITHDRAW_01: Withdraw must deduct from the sender in wad";

    string internal constant GENERAL_01 = "GENERAL_01: loan.faceValue <= FOL(loan).faceValue";

    function invariant_GENERAL_01() public returns (bool) {
        uint256 activeLoans = size.activeLoans();
        for (uint256 loanId; loanId < activeLoans; loanId++) {
            if (!size.isFOL(loanId)) {
                Loan memory loan = size.getLoan(loanId);
                Loan memory fol = size.getLoan(loan.folId);
                if (!(loan.faceValue <= fol.faceValue)) {
                    t(false, GENERAL_01);
                    return false;
                }
            }
        }
        return true;
    }
}
