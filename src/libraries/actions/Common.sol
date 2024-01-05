// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";
import {Loan, LoanLibrary, LoanStatus, RESERVED_ID, VariableLoan} from "@src/libraries/LoanLibrary.sol";
import {Math} from "@src/libraries/MathLibrary.sol";

library Common {
    using LoanLibrary for Loan;

    function reduceDebt(State storage state, uint256 loanId, uint256 amount) public {
        Loan storage loan = state.loans[loanId];
        if (amount > loan.getCredit()) {
            revert Errors.NOT_ENOUGH_CREDIT(loan.getCredit(), amount);
        }

        loan.faceValue -= amount;
        state.tokens.debtToken.burn(loan.borrower, amount);
    }

    function validateMinimumCredit(State storage state, uint256 credit) public view {
        if (credit < state.config.minimumCredit) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state.config.minimumCredit);
        }
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(State storage state, address lender, address borrower, uint256 faceValue, uint256 dueDate)
        public
    {
        Loan memory fol = Loan({
            faceValue: faceValue,
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            dueDate: dueDate,
            repaid: false,
            folId: RESERVED_ID
        });
        validateMinimumCredit(state, fol.getCredit());

        state.loans.push(fol);
        uint256 folId = state.loans.length - 1;

        emit Events.CreateLoan(folId, lender, borrower, RESERVED_ID, RESERVED_ID, faceValue, dueDate);
    }

    // solhint-disable-next-line var-name-mixedcase
    function createSOL(State storage state, uint256 exiterId, address lender, address borrower, uint256 faceValue)
        public
    {
        uint256 folId = getFOLId(state, exiterId);
        Loan storage fol = state.loans[folId];

        Loan memory sol = Loan({
            faceValue: faceValue,
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            dueDate: fol.dueDate,
            repaid: false,
            folId: folId
        });

        validateMinimumCredit(state, sol.getCredit());
        state.loans.push(sol);
        uint256 solId = state.loans.length - 1;

        Loan storage exiter = state.loans[exiterId];
        exiter.faceValueExited += faceValue;
        uint256 exiterCredit = exiter.getCredit();

        if (exiterCredit > 0) {
            validateMinimumCredit(state, exiterCredit);
        }

        emit Events.CreateLoan(solId, lender, borrower, exiterId, folId, faceValue, fol.dueDate);
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

    function getFOL(State storage state, Loan storage self) public view returns (Loan storage) {
        return self.isFOL() ? self : state.loans[self.folId];
    }

    function getFOLId(State storage state, uint256 loanId) public view returns (uint256) {
        Loan storage loan = state.loans[loanId];
        return loan.isFOL() ? loanId : loan.folId;
    }

    function getLoanStatus(State storage state, Loan storage self) public view returns (LoanStatus) {
        if (self.faceValueExited == self.faceValue) {
            return LoanStatus.CLAIMED;
        } else if (getFOL(state, self).repaid) {
            return LoanStatus.REPAID;
        } else if (block.timestamp >= self.dueDate) {
            return LoanStatus.OVERDUE;
        } else {
            return LoanStatus.ACTIVE;
        }
    }

    function either(State storage state, Loan storage self, LoanStatus[2] memory status) public view returns (bool) {
        return getLoanStatus(state, self) == status[0] || getLoanStatus(state, self) == status[1];
    }

    function getFOLAssignedCollateral(State storage state, Loan memory loan) public view returns (uint256) {
        if (!loan.isFOL()) revert Errors.NOT_SUPPORTED();

        uint256 debt = state.tokens.debtToken.balanceOf(loan.borrower);
        uint256 collateral = state.tokens.collateralToken.balanceOf(loan.borrower);
        if (debt > 0) {
            return Math.mulDivDown(collateral, loan.faceValue, debt);
        } else {
            return 0;
        }
    }

    function getProRataAssignedCollateral(State storage state, uint256 loanId) public view returns (uint256) {
        Loan storage loan = state.loans[loanId];
        Loan storage fol = getFOL(state, loan);
        uint256 folCollateral = getFOLAssignedCollateral(state, fol);
        return Math.mulDivDown(folCollateral, loan.getCredit(), fol.getDebt());
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state.tokens.collateralToken.balanceOf(account);
        uint256 debt = state.tokens.debtToken.balanceOf(account);
        uint256 price = state.config.priceFeed.getPrice();

        if (debt > 0) {
            return Math.mulDivDown(collateral, price, debt);
        } else {
            return type(uint256).max;
        }
    }

    function isLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state.config.crLiquidation;
    }

    function validateUserIsNotLiquidatable(State storage state, address account) external view {
        if (isLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(account, collateralRatio(state, account));
        }
    }

    function getMinimumCollateralOpening(State storage state, uint256 faceValue) public view returns (uint256) {
        return Math.mulDivUp(faceValue, state.config.crOpening, state.config.priceFeed.getPrice());
    }
}
