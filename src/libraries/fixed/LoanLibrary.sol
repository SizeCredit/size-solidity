// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

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
    uint256 repayFeeAPR;
    uint256 startDate;
    uint256 dueDate;
    uint256 liquidityIndexAtRepayment;
}

struct SOL {
    uint256 folId;
}

struct Loan {
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
enum LoanStatus {
    ACTIVE, // not yet due
    OVERDUE, // eligible to liquidation
    REPAID, // by borrower or liquidator
    CLAIMED // by lender

}

library LoanLibrary {
    using AccountingLibrary for Loan;
    using AccountingLibrary for State;

    function isFOL(Loan memory self) internal pure returns (bool) {
        return self.sol.folId == RESERVED_ID;
    }

    function getDebt(Loan memory fol) internal pure returns (uint256) {
        return faceValue(fol) + maximumRepayFee(fol);
    }

    function faceValue(Loan memory self) internal pure returns (uint256) {
        return Math.mulDivUp(self.fol.issuanceValue, PERCENT + self.fol.rate, PERCENT);
    }

    function getFOL(State storage state, Loan storage loan) public view returns (Loan storage) {
        return isFOL(loan) ? loan : state.data.loans[loan.sol.folId];
    }

    function getFOLId(State storage state, uint256 loanId) public view returns (uint256) {
        Loan storage loan = state.data.loans[loanId];
        return isFOL(loan) ? loanId : loan.sol.folId;
    }

    function getLoanStatus(State storage state, Loan storage self) public view returns (LoanStatus) {
        Loan storage fol = getFOL(state, self);
        if (self.generic.credit == 0) {
            return LoanStatus.CLAIMED;
        } else if (getDebt(fol) == 0) {
            return LoanStatus.REPAID;
        } else if (block.timestamp >= fol.fol.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    function either(State storage state, Loan storage self, LoanStatus[2] memory status) public view returns (bool) {
        return getLoanStatus(state, self) == status[0] || getLoanStatus(state, self) == status[1];
    }

    function either(LoanStatus s, LoanStatus[2] memory status) public pure returns (bool) {
        return s == status[0] || s == status[1];
    }

    // assumes fees are already paid
    function getFOLAssignedCollateral(State storage state, Loan memory fol) public view returns (uint256) {
        if (!isFOL(fol)) revert Errors.NOT_SUPPORTED();

        uint256 debt = state.data.debtToken.balanceOf(fol.generic.borrower);
        uint256 collateral = state.data.collateralToken.balanceOf(fol.generic.borrower);

        if (debt > 0) {
            return Math.mulDivDown(collateral, faceValue(fol), debt);
        } else {
            return 0;
        }
    }

    // assumes fees are already paid
    function getProRataAssignedCollateral(State storage state, uint256 loanId) public view returns (uint256) {
        Loan storage loan = state.data.loans[loanId];
        Loan storage fol = getFOL(state, loan);
        uint256 loanCredit = loan.generic.credit;
        uint256 folCollateral = getFOLAssignedCollateral(state, fol);
        uint256 folFaceValue = faceValue(fol);

        if (folFaceValue > 0) {
            return Math.mulDivDown(folCollateral, loanCredit, folFaceValue);
        } else {
            return 0;
        }
    }

    function maximumRepayFee(uint256 issuanceValue, uint256 startDate, uint256 dueDate, uint256 repayFeeAPR)
        internal
        pure
        returns (uint256)
    {
        uint256 interval = dueDate - startDate;
        uint256 repayFeePercent = Math.mulDivUp(repayFeeAPR, interval, 365 days);
        uint256 fee = Math.mulDivUp(issuanceValue, repayFeePercent, PERCENT);
        return fee;
    }

    function maximumRepayFee(Loan memory fol) internal pure returns (uint256) {
        return maximumRepayFee(fol.fol.issuanceValue, fol.fol.startDate, fol.fol.dueDate, fol.fol.repayFeeAPR);
    }

    function partialRepayFee(Loan memory fol, uint256 repayAmount) internal pure returns (uint256) {
        // pending question about calculating parial repay fee
        return Math.mulDivUp(repayAmount, maximumRepayFee(fol), faceValue(fol));
    }
}
