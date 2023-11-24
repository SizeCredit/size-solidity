// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@src/libraries/MathLibrary.sol";
import "@src/libraries/UserLibrary.sol";

struct Loan {
    // FOL
    uint256 FV;
    uint256 amountFVExited;
    address lender;
    address borrower;
    uint256 dueDate;
    bool repaid;
    bool claimed;
    uint256 folId; // non-null for SOLs
}

enum LoanStatus {
    ACTIVE, // not yet due
    OVERDUE, // eligible to liquidation
    REPAID, // by borrower or liquidator
    CLAIMED // by lender
}

struct VariableLoan {
    address borrower;
    uint256 amountUSDCLentOut;
    uint256 amountCollateral;
}

library LoanLibrary {
    using UserLibrary for User;

    error LoanLibrary__InvalidLoan(uint256 folId);
    error LoanLibrary__InvalidAmount(uint256 amount, uint256 maxExit);

    function isFOL(Loan memory self) public pure returns (bool) {
        return self.folId == 0;
    }

    function getLoanStatus(Loan memory self, Loan[] memory loans) public view returns (LoanStatus) {
        if (self.claimed) {
            return LoanStatus.CLAIMED;
        } else if (self.repaid) {
            return LoanStatus.REPAID;
        } else if (block.timestamp > getDueDate(self, loans)) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    function getCredit(Loan memory self) public pure returns (uint256) {
        return self.FV - self.amountFVExited;
    }

    function getDebt(Loan memory self, bool inCollateral, uint256 price) public pure returns (uint256) {
        return inCollateral ? (self.FV * 1e18) / price : self.FV;
    }

    function perc(Loan memory self, Loan[] memory loans) public pure returns (uint256) {
        return (PERCENT * getCredit(self)) / (isFOL(self) ? self.FV : loans[self.folId].FV);
    }

    function getDueDate(Loan memory self, Loan[] memory loans) public pure returns (uint256) {
        return isFOL(self) ? self.dueDate : loans[self.folId].dueDate;
    }

    function getFOL(Loan memory self, Loan[] memory loans) public pure returns (Loan memory) {
        return isFOL(self) ? self : loans[self.folId];
    }

    function isRepaid(Loan memory self, Loan[] memory loans) public pure returns (bool) {
        return isFOL(self) ? self.repaid : loans[self.folId].repaid;
    }

    function isExpired(Loan memory self) public view returns (bool) {
        if (isFOL(self)) {
            return block.timestamp >= self.dueDate;
        } else {
            revert LoanLibrary__InvalidLoan(self.folId);
        }
    }

    function createFOL(Loan[] storage loans, address lender, address borrower, uint256 FV, uint256 dueDate) public {
        loans.push(
            Loan({
                FV: FV,
                amountFVExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: dueDate,
                repaid: false,
                claimed: false,
                folId: 0
            })
        );
    }

    function createSOL(Loan[] storage loans, uint256 folId, address lender, address borrower, uint256 FV) public {
        Loan storage fol = loans[folId];
        loans.push(
            Loan({
                FV: FV,
                amountFVExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: fol.dueDate,
                repaid: false,
                claimed: false,
                folId: folId
            })
        );
        if (FV > getCredit(fol)) {
            revert LoanLibrary__InvalidAmount(FV, getCredit(fol));
        }
        fol.amountFVExited += FV;
    }
}
