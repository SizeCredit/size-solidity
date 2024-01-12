// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {
    FixedLoan,
    FixedLoanLibrary,
    FixedLoanStatus,
    RESERVED_ID,
    VariableFixedLoan
} from "@src/libraries/FixedLoanLibrary.sol";
import {Math} from "@src/libraries/MathLibrary.sol";

library Common {
    using FixedLoanLibrary for FixedLoan;

    function reduceDebt(State storage state, uint256 loanId, uint256 amount) public {
        FixedLoan storage loan = state.loans[loanId];
        FixedLoan storage fol = getFOL(state, loan);

        state.f.debtToken.burn(fol.borrower, amount);

        loan.faceValue -= amount;
        validateMinimumCredit(state, loan.getCredit());

        if (!loan.isFOL()) {
            fol.faceValue -= amount;
            fol.faceValueExited -= amount;
        }
    }

    function validateMinimumCredit(State storage state, uint256 credit) public view {
        if (0 < credit && credit < state.f.minimumCredit) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state.f.minimumCredit);
        }
    }

    function validateMinimumCreditOpening(State storage state, uint256 credit) public view {
        if (credit < state.f.minimumCredit) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state.f.minimumCredit);
        }
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(State storage state, address lender, address borrower, uint256 faceValue, uint256 dueDate)
        public
    {
        FixedLoan memory fol = FixedLoan({
            faceValue: faceValue,
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            dueDate: dueDate,
            repaid: false,
            folId: RESERVED_ID
        });
        validateMinimumCreditOpening(state, fol.getCredit());

        state.loans.push(fol);
        uint256 folId = state.loans.length - 1;

        emit Events.CreateFixedLoan(folId, lender, borrower, RESERVED_ID, RESERVED_ID, faceValue, dueDate);
    }

    // solhint-disable-next-line var-name-mixedcase
    function createSOL(State storage state, uint256 exiterId, address lender, address borrower, uint256 faceValue)
        public
    {
        uint256 folId = getFOLId(state, exiterId);
        FixedLoan storage fol = state.loans[folId];

        FixedLoan memory sol = FixedLoan({
            faceValue: faceValue,
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            dueDate: fol.dueDate,
            repaid: false,
            folId: folId
        });

        validateMinimumCreditOpening(state, sol.getCredit());
        state.loans.push(sol);
        uint256 solId = state.loans.length - 1;

        FixedLoan storage exiter = state.loans[exiterId];
        exiter.faceValueExited += faceValue;
        validateMinimumCredit(state, exiter.getCredit());

        emit Events.CreateFixedLoan(solId, lender, borrower, exiterId, folId, faceValue, fol.dueDate);
    }

    function createVariableFixedLoan(
        State storage state,
        address borrower,
        uint256 amountBorrowAssetLentOut,
        uint256 amountCollateral
    ) public {
        state.variableFixedLoans.push(
            VariableFixedLoan({
                borrower: borrower,
                amountBorrowAssetLentOut: amountBorrowAssetLentOut,
                amountCollateral: amountCollateral,
                startTime: block.timestamp,
                repaid: false
            })
        );
    }

    function getFOL(State storage state, FixedLoan storage self) public view returns (FixedLoan storage) {
        return self.isFOL() ? self : state.loans[self.folId];
    }

    function getFOLId(State storage state, uint256 loanId) public view returns (uint256) {
        FixedLoan storage loan = state.loans[loanId];
        return loan.isFOL() ? loanId : loan.folId;
    }

    function getFixedLoanStatus(State storage state, FixedLoan storage self) public view returns (FixedLoanStatus) {
        if (self.faceValueExited == self.faceValue) {
            return FixedLoanStatus.CLAIMED;
        } else if (getFOL(state, self).repaid) {
            return FixedLoanStatus.REPAID;
        } else if (block.timestamp >= self.dueDate) {
            return FixedLoanStatus.OVERDUE;
        } else {
            return FixedLoanStatus.ACTIVE;
        }
    }

    function either(State storage state, FixedLoan storage self, FixedLoanStatus[2] memory status)
        public
        view
        returns (bool)
    {
        return getFixedLoanStatus(state, self) == status[0] || getFixedLoanStatus(state, self) == status[1];
    }

    function getFOLAssignedCollateral(State storage state, FixedLoan memory loan) public view returns (uint256) {
        if (!loan.isFOL()) revert Errors.NOT_SUPPORTED();

        uint256 debt = state.f.debtToken.balanceOf(loan.borrower);
        uint256 collateral = state.f.collateralToken.balanceOf(loan.borrower);
        if (debt > 0) {
            return Math.mulDivDown(collateral, loan.faceValue, debt);
        } else {
            return 0;
        }
    }

    function getProRataAssignedCollateral(State storage state, uint256 loanId) public view returns (uint256) {
        FixedLoan storage loan = state.loans[loanId];
        FixedLoan storage fol = getFOL(state, loan);
        uint256 folCollateral = getFOLAssignedCollateral(state, fol);
        return Math.mulDivDown(folCollateral, loan.getCredit(), fol.getDebt());
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state.f.collateralToken.balanceOf(account);
        uint256 debt = state.f.debtToken.balanceOf(account);
        uint256 price = state.g.priceFeed.getPrice();

        if (debt > 0) {
            return Math.mulDivDown(collateral, price, debt);
        } else {
            return type(uint256).max;
        }
    }

    function isLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state.f.crLiquidation;
    }

    function validateUserIsNotLiquidatable(State storage state, address account) external view {
        if (isLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(account, collateralRatio(state, account));
        }
    }

    function getMinimumCollateralOpening(State storage state, uint256 faceValue) public view returns (uint256) {
        return Math.mulDivUp(faceValue, state.f.crOpening, state.g.priceFeed.getPrice());
    }
}
