// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./MathLibrary.sol";
import "./UserLibrary.sol";

struct Loan {
    uint256 FV;
    uint256 amountFVExited;
}

struct FOL {
    Loan loan;
    address lender;
    address borrower;
    uint256 dueDate;
    uint256 FVCoveredByRealCollateral;
}

struct SOL {
    Loan loan;
    FOL fol;
    address lender;
}

library LoanLibrary {
    function maxExit(Loan storage self) public view returns (uint256) {
        return self.FV - self.amountFVExited;
    }
}

library FOLLibrary {
    using LoanLibrary for Loan;

    function perc(FOL storage self) public view returns (uint256) {
        return PERCENT * self.loan.maxExit() / self.loan.FV;
    }

    function isExpired(FOL storage self) public view returns(bool) {
        return block.timestamp >= self.dueDate;
    }
}

library SOLLibrary {
    using LoanLibrary for Loan;

    function perc(SOL storage self) public view returns (uint256) {
        return PERCENT * self.loan.maxExit() / self.fol.loan.FV;
    }
}