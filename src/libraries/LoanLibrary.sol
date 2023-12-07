// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

struct Loan {
    // FOL
    uint256 FV;
    uint256 amountFVExited;
    address lender;
    address borrower;
    uint256 dueDate;
    bool repaid;
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
    uint256 amountBorrowAssetLentOut;
    uint256 amountCollateral;
}

library LoanLibrary {
    error LoanLibrary__InvalidAmount(uint256 amount, uint256 maxExit);

    function isFOL(Loan memory self) public pure returns (bool) {
        return self.folId == 0;
    }

    function getLoanStatus(Loan memory self, Loan[] memory loans) public view returns (LoanStatus) {
        if (self.repaid) {
            if (self.amountFVExited == self.FV) {
                return LoanStatus.CLAIMED;
            } else {
                return LoanStatus.REPAID;
            }
        } else if (isOverdue(self, loans)) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    function either(Loan memory self, Loan[] memory loans, LoanStatus[2] memory status) public view returns (bool) {
        return getLoanStatus(self, loans) == status[0] || getLoanStatus(self, loans) == status[1];
    }

    function getCredit(Loan memory self) public pure returns (uint256) {
        return self.FV - self.amountFVExited;
    }

    function getDebt(Loan memory self) public pure returns (uint256) {
        return self.FV;
    }

    function getDueDate(Loan memory self, Loan[] memory loans) public pure returns (uint256) {
        return isFOL(self) ? self.dueDate : loans[self.folId].dueDate;
    }

    function isOverdue(Loan memory self, Loan[] memory loans) public view returns (bool) {
        return block.timestamp >= getDueDate(self, loans);
    }

    function createFOL(Loan[] storage loans, address lender, address borrower, uint256 FV, uint256 dueDate)
        public
        returns (uint256 folId)
    {
        loans.push(
            Loan({
                FV: FV,
                amountFVExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: dueDate,
                repaid: false,
                folId: 0
            })
        );
        folId = loans.length - 1;

        emit Events.CreateLoan(folId, lender, borrower, 0, FV, dueDate);
    }

    function createSOL(Loan[] storage loans, uint256 folId, address lender, address borrower, uint256 FV)
        public
        returns (uint256 solId)
    {
        Loan storage fol = loans[folId];
        loans.push(
            Loan({
                FV: FV,
                amountFVExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: fol.dueDate,
                repaid: false,
                folId: folId
            })
        );
        if (FV > getCredit(fol)) {
            // @audit this has 0 coverage, I believe it is already checked by _borrowWithVirtualCollateral & validateExit
            revert Errors.NOT_ENOUGH_FREE_CASH(getCredit(fol), FV);
        }
        fol.amountFVExited += FV;

        solId = loans.length - 1;

        emit Events.CreateLoan(solId, lender, borrower, folId, FV, fol.dueDate);
    }
}
