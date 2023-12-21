// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

uint256 constant RESERVED_FOL_ID = type(uint256).max;

struct Loan {
    // solhint-disable-next-line var-name-mixedcase
    uint256 FV; // FOL/SOL
    uint256 amountFVExited; // FOL
    address lender; // FOL/SOL
    address borrower; // FOL/SOL
    uint256 dueDate; // FOL
    bool repaid; // FOL
    uint256 folId; // SOL
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
        return self.folId == RESERVED_FOL_ID;
    }

    function getFOL(Loan storage self, Loan[] storage loans) public view returns (Loan storage) {
        return isFOL(self) ? self : loans[self.folId];
    }

    function getLoanStatus(Loan memory self) public view returns (LoanStatus) {
        if (self.amountFVExited == self.FV) {
            return LoanStatus.CLAIMED;
            // @audit If this is a SOL, should I get the .repaid information from the FOL?
        } else if (self.repaid) {
            return LoanStatus.REPAID;
        } else if (block.timestamp >= self.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    function either(Loan memory self, LoanStatus[2] memory status) public view returns (bool) {
        return getLoanStatus(self) == status[0] || getLoanStatus(self) == status[1];
    }

    function getCredit(Loan memory self) public pure returns (uint256) {
        return self.FV - self.amountFVExited;
    }

    function getDebt(Loan memory self) public pure returns (uint256) {
        return self.FV;
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(Loan[] storage loans, address lender, address borrower, uint256 FV, uint256 dueDate) public {
        loans.push(
            Loan({
                FV: FV,
                amountFVExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: dueDate,
                repaid: false,
                folId: RESERVED_FOL_ID
            })
        );
        uint256 folId = loans.length - 1;

        emit Events.CreateLoan(folId, lender, borrower, RESERVED_FOL_ID, FV, dueDate);
    }

    // solhint-disable-next-line var-name-mixedcase
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
        if (FV > getCredit(fol)) {
            // @audit this has 0 coverage,
            //   I believe it is already checked by _borrowWithVirtualCollateral & validateExit
            revert Errors.NOT_ENOUGH_FREE_CASH(getCredit(fol), FV);
        }
        fol.amountFVExited += FV;

        uint256 solId = loans.length - 1;

        emit Events.CreateLoan(solId, lender, borrower, folId, FV, fol.dueDate);
    }

    function createVariableLoan(
        VariableLoan[] storage variableLoans,
        address borrower,
        uint256 amountBorrowAssetLentOut,
        uint256 amountCollateral
    ) public {
        variableLoans.push(
            VariableLoan({
                borrower: borrower,
                amountBorrowAssetLentOut: amountBorrowAssetLentOut,
                amountCollateral: amountCollateral,
                startTime: block.timestamp,
                repaid: false
            })
        );
    }

    function getDebtCurrent(VariableLoan storage self, uint256 ratePerUnitTime) internal view returns (uint256) {
        uint256 r = PERCENT + ratePerUnitTime * (block.timestamp - self.startTime);
        return FixedPointMathLib.mulDivUp(self.amountBorrowAssetLentOut, r, PERCENT);
    }

    function getCollateralRatio(VariableLoan storage self, uint256 ratePerUnitTime, uint256 price)
        internal
        view
        returns (uint256)
    {
        uint256 debt = getDebtCurrent(self, ratePerUnitTime);
        return FixedPointMathLib.mulDivDown(self.amountCollateral, price, debt);
    }
}
