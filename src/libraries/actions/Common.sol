// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Loan, VariableLoan, LoanLibrary, LoanStatus, RESERVED_FOL_ID} from "@src/libraries/LoanLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

library Common {
    using LoanLibrary for Loan;

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(State storage state, address lender, address borrower, uint256 faceValue, uint256 dueDate)
        public
    {
        state.loans.push(
            Loan({
                faceValue: faceValue,
                faceValueExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: dueDate,
                repaid: false,
                folId: RESERVED_FOL_ID
            })
        );
        uint256 folId = state.loans.length - 1;

        emit Events.CreateLoan(folId, lender, borrower, RESERVED_FOL_ID, faceValue, dueDate);
    }

    // solhint-disable-next-line var-name-mixedcase
    function createSOL(State storage state, uint256 folId, address lender, address borrower, uint256 faceValue)
        public
    {
        Loan storage fol = state.loans[folId];
        state.loans.push(
            Loan({
                faceValue: faceValue,
                faceValueExited: 0,
                lender: lender,
                borrower: borrower,
                dueDate: fol.dueDate,
                repaid: false,
                folId: folId
            })
        );
        if (faceValue > fol.getCredit()) {
            // @audit this has 0 coverage,
            //   I believe it is already checked by _borrowWithVirtualCollateral & validateExit
            revert Errors.NOT_ENOUGH_FREE_CASH(fol.getCredit(), faceValue);
        }
        fol.faceValueExited += faceValue;

        uint256 solId = state.loans.length - 1;

        emit Events.CreateLoan(solId, lender, borrower, folId, faceValue, fol.dueDate);
    }

    function createVariableLoan(
        State storage state,
        address borrower,
        uint256 amountBorrowAssetLentOut,
        uint256 amountCollateral
    ) public {
        state.variableLoans.push(
            VariableLoan({
                borrower: borrower,
                amountBorrowAssetLentOut: amountBorrowAssetLentOut,
                amountCollateral: amountCollateral,
                startTime: block.timestamp,
                repaid: false
            })
        );
    }


    function _getFOL(State storage state, Loan memory self) internal view returns (Loan memory) {
        return self.isFOL() ? self : state.loans[self.folId];
    }

    function getFOL(State storage state, Loan storage self) public view returns (Loan storage) {
        return self.isFOL() ? self : state.loans[self.folId];
    }

    function getLoanStatus(State storage state, Loan memory self) public view returns (LoanStatus) {
        if (self.faceValueExited == self.faceValue) {
            return LoanStatus.CLAIMED;
        } else if (_getFOL(state, self).repaid) {
            return LoanStatus.REPAID;
        } else if (block.timestamp >= self.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    function either(State storage state, Loan memory self, LoanStatus[2] memory status) public view returns (bool) {
        return getLoanStatus(state, self) == status[0] || getLoanStatus(state, self) == status[1];
    }

}
