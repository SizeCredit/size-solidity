// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./MathLibrary.sol";
import "./UserLibrary.sol";

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

    function getCredit(Loan memory self) public pure returns (uint256) {
        return self.FV - self.amountFVExited;
    }

    function getDebt(Loan memory self, bool inCollateral, uint256 price) public pure returns (uint256) {
        return inCollateral ? self.FV * 1e18 / price : self.FV;
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

    function lock(Loan storage self, uint256 amount) public {
        if (amount > getCredit(self)) {
            revert LoanLibrary__InvalidAmount(amount, getCredit(self));
        }
        self.amountFVExited += amount;
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
                folId: folId
            })
        );
        lock(fol, FV);
    }
}
