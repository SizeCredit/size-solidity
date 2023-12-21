// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Loan, LoanLibrary, LoanStatus, RESERVED_FOL_ID, VariableLoan} from "@src/libraries/LoanLibrary.sol";

library Common {
    using LoanLibrary for Loan;

    function validateMinimumFaceValueFOL(State storage state, uint256 faceValue) public view {
        if (faceValue < state.minimumFaceValue) {
            revert Errors.FACE_VALUE_LOWER_THAN_MINIMUM_FACE_VALUE_FOL(faceValue, state.minimumFaceValue);
        }
    }

    function validateMinimumFaceValueSOL(State storage state, uint256 faceValue) public view {
        if (faceValue < state.minimumFaceValue) {
            revert Errors.FACE_VALUE_LOWER_THAN_MINIMUM_FACE_VALUE_SOL(faceValue, state.minimumFaceValue);
        }
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(State storage state, address lender, address borrower, uint256 faceValue, uint256 dueDate)
        public
    {
        validateMinimumFaceValueFOL(state, faceValue);

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
        validateMinimumFaceValueSOL(state, faceValue);
        if (faceValue > fol.getCredit()) {
            // @audit this has 0 coverage,
            //   I believe it is already checked by _borrowWithVirtualCollateral & validateExit
            revert Errors.NOT_ENOUGH_FREE_CASH(fol.getCredit(), faceValue);
        }

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

    function getAssignedCollateral(State storage state, Loan memory loan) public view returns (uint256) {
        uint256 debt = state.debtToken.balanceOf(loan.borrower);
        uint256 collateral = state.collateralToken.balanceOf(loan.borrower);
        if (debt > 0) {
            return FixedPointMathLib.mulDivDown(collateral, loan.faceValue, debt);
        } else {
            return 0;
        }
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state.collateralToken.balanceOf(account);
        uint256 debt = state.debtToken.balanceOf(account);
        uint256 price = state.priceFeed.getPrice();

        if (debt > 0) {
            return FixedPointMathLib.mulDivDown(collateral, price, debt);
        } else {
            return type(uint256).max;
        }
    }

    function isLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state.crLiquidation;
    }

    function validateUserIsNotLiquidatable(State storage state, address account) external view {
        if (isLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(account, collateralRatio(state, account));
        }
    }

    function getMinimumCollateralOpening(State storage state, uint256 faceValue) public view returns (uint256) {
        return FixedPointMathLib.mulDivUp(faceValue, state.crOpening, state.priceFeed.getPrice());
    }
}
