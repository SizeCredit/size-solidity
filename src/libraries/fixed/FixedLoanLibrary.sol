// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console} from "forge-std/console.sol";

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {AccountingLibrary} from "@src/libraries/fixed/AccountingLibrary.sol";

uint256 constant RESERVED_ID = type(uint256).max;

struct GenericLoan {
    address lender;
    address borrower;
    uint256 credit;
}

struct FOL {
    uint256 issuanceValue; // updated on repayment
    uint256 rate;
    uint256 startDate;
    uint256 dueDate;
    uint256 liquidityIndexAtRepayment;
}

struct SOL {
    uint256 folId;
}

struct FixedLoan {
    GenericLoan generic;
    FOL fol;
    SOL sol;
}

// When the loan is created, it is in ACTIVE status
// When maturity is reached, it is in OVERDUE status
// If the loan is not repaid and the CR is sufficient, it is moved to the Variable Pool,
//   otherwise it is eligible for liquidation but if the CR < 100% then it will remain in
//   the overdue state until the CR is > 100% or the lenders perform self liquidation
// When the loan is repaid either by the borrower or by the liquidator, it is in REPAID status
// When the loan is claimed by the lender or if it has been fully exited, it is in CLAIMED status
enum FixedLoanStatus {
    ACTIVE, // not yet due
    OVERDUE, // eligible to liquidation
    REPAID, // by borrower or liquidator
    CLAIMED // by lender

}

library FixedLoanLibrary {
    using AccountingLibrary for FixedLoan;
    using AccountingLibrary for State;

    function isFOL(FixedLoan memory self) internal pure returns (bool) {
        return self.sol.folId == RESERVED_ID;
    }

    function getDebt(State storage state, FixedLoan memory fol) internal view returns (uint256) {
        return faceValue(fol) + state.maximumRepayFee(fol);
    }

    function faceValue(FixedLoan memory self) internal pure returns (uint256) {
        return Math.mulDivUp(self.fol.issuanceValue, PERCENT + self.fol.rate, PERCENT);
    }

    function getFOL(State storage state, FixedLoan storage loan) public view returns (FixedLoan storage) {
        return isFOL(loan) ? loan : state._fixed.loans[loan.sol.folId];
    }

    function getFOLId(State storage state, uint256 loanId) public view returns (uint256) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        return isFOL(loan) ? loanId : loan.sol.folId;
    }

    function getFixedLoanStatus(State storage state, FixedLoan storage self) public view returns (FixedLoanStatus) {
        FixedLoan storage fol = getFOL(state, self);
        if (self.generic.credit == 0) {
            return FixedLoanStatus.CLAIMED;
        } else if (getDebt(state, fol) == 0) {
            return FixedLoanStatus.REPAID;
        } else if (block.timestamp >= fol.fol.dueDate) {
            return FixedLoanStatus.OVERDUE;
        } else {
            return FixedLoanStatus.ACTIVE;
        }
    }

    function either(State storage state, FixedLoan storage self, FixedLoanStatus[2] memory status)
        public
        view
        returns (bool)
    {
        return getFixedLoanStatus(state, self) == status[0] || getFixedLoanStatus(state, self) == status[1];
    }

    function either(FixedLoanStatus s, FixedLoanStatus[2] memory status) public pure returns (bool) {
        return s == status[0] || s == status[1];
    }

    function getFOLAssignedCollateral(State storage state, FixedLoan memory fol) public view returns (uint256) {
        if (!isFOL(fol)) revert Errors.NOT_SUPPORTED();

        uint256 folDebt = getDebt(state, fol);
        uint256 debt = state._fixed.debtToken.balanceOf(fol.generic.borrower);
        uint256 collateral = state._fixed.collateralToken.balanceOf(fol.generic.borrower);

        if (debt > 0) {
            return Math.mulDivDown(collateral, folDebt, debt);
        } else {
            return 0;
        }
    }

    function getProRataAssignedCollateral(State storage state, uint256 loanId) public view returns (uint256) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoan storage fol = getFOL(state, loan);
        uint256 loanCredit = loan.generic.credit;
        uint256 folCollateral = getFOLAssignedCollateral(state, fol);
        uint256 folDebt = getDebt(state, fol);

        if (folDebt > 0) {
            return Math.mulDivDown(folCollateral, loanCredit, folDebt);
        } else {
            return 0;
        }
    }
}
