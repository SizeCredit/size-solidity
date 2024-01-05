// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

uint256 constant RESERVED_ID = type(uint256).max;

struct Loan {
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

enum LoanStatus {
    ACTIVE, // not yet due
    OVERDUE, // eligible to liquidation
    REPAID, // by borrower or liquidator
    CLAIMED // by lender

}

struct VariableLoan {
    address borrower;
    uint256 amountBorrowAssetLentOut;
    uint256 amountCollateral;
    uint256 startTime;
    bool repaid;
}

library LoanLibrary {
    function isFOL(Loan memory self) public pure returns (bool) {
        return self.folId == RESERVED_ID;
    }

    function getCredit(Loan memory self) public pure returns (uint256) {
        return self.faceValue - self.faceValueExited;
    }

    function getDebt(Loan memory self) public pure returns (uint256) {
        return self.faceValue;
    }
}
