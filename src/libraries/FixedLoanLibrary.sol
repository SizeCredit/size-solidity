// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

uint256 constant RESERVED_ID = type(uint256).max;

struct FixedLoan {
    // generic
    uint256 faceValue;
    uint256 faceValueExited;
    address lender;
    address borrower;
    // FOL-specific
    uint256 dueDate;
    bool repaid;
    // SOL-specific
    uint256 folId;
}

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

    function getDebt(FixedLoan memory self) internal pure returns (uint256) {
        return self.faceValue;
    }
}
