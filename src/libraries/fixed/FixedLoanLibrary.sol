// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

uint256 constant RESERVED_ID = type(uint256).max;

struct FixedLoan {
    uint256 faceValue;
    uint256 faceValueExited;
    address lender;
    address borrower;
    uint256 dueDate; // same for FOL and SOL
    uint256 liquidityIndexAtRepayment; // FOL-specific
    uint256 repaymentFee; // FOL-specific
    uint256 folId; // SOL-specific
    bool repaid; // FOL-specific
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
    function isFOL(FixedLoan memory self) internal pure returns (bool) {
        return self.folId == RESERVED_ID;
    }

    function getCredit(FixedLoan memory self) internal pure returns (uint256) {
        return self.faceValue - self.faceValueExited;
    }
}
