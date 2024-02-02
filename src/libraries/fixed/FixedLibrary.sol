// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Events} from "@src/libraries/Events.sol";

import {Math, PERCENT} from "@src/libraries/Math.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus, RESERVED_ID} from "@src/libraries/fixed/FixedLoanLibrary.sol";

library FixedLibrary {
    using FixedLoanLibrary for FixedLoan;

    function reduceDebt(State storage state, uint256 loanId, uint256 amount) public {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoan storage fol = getFOL(state, loan);

        state._fixed.debtToken.burn(fol.borrower, amount);

        loan.faceValue -= amount;
        validateMinimumCredit(state, loan.getCredit());

        if (!loan.isFOL()) {
            fol.faceValue -= amount;
            fol.faceValueExited -= amount;
        }
    }

    function validateMinimumCredit(State storage state, uint256 credit) public view {
        if (0 < credit && credit < state._fixed.minimumCreditBorrowAsset) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state._fixed.minimumCreditBorrowAsset);
        }
    }

    function validateMinimumCreditOpening(State storage state, uint256 credit) public view {
        if (credit < state._fixed.minimumCreditBorrowAsset) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state._fixed.minimumCreditBorrowAsset);
        }
    }

    function validateRepaymentFee(State storage, FixedLoan memory fol) internal pure {
        if(fol.repaymentFee > fol.faceValue) {
            revert Errors.INVALID_REPAYMENT_FEE(fol.repaymentFee, fol.faceValue);
        }
    }

    // solhint-disable-next-line var-name-mixedcase
    function createFOL(State storage state, address lender, address borrower, uint256 faceValue, uint256 dueDate)
        public
    {
        uint256 repaymentFee = Math.mulDivUp(faceValue, state._fixed.repaymentFeeAPR, PERCENT);
        FixedLoan memory fol = FixedLoan({
            faceValue: faceValue,
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            dueDate: dueDate,
            repaid: false,
            liquidityIndexAtRepayment: 0,
            repaymentFee: repaymentFee,
            folId: RESERVED_ID
        });
        validateMinimumCreditOpening(state, fol.getCredit());
        validateRepaymentFee(state, fol);

        state._fixed.loans.push(fol);
        uint256 folId = state._fixed.loans.length - 1;

        emit Events.CreateFixedLoan(folId, lender, borrower, RESERVED_ID, RESERVED_ID, faceValue, dueDate);
    }

    // solhint-disable-next-line var-name-mixedcase
    function createSOL(State storage state, uint256 exiterId, address lender, address borrower, uint256 faceValue)
        public
    {
        uint256 folId = getFOLId(state, exiterId);
        FixedLoan storage fol = state._fixed.loans[folId];

        FixedLoan memory sol = FixedLoan({
            faceValue: faceValue,
            faceValueExited: 0,
            lender: lender,
            borrower: borrower,
            dueDate: fol.dueDate,
            repaid: false,
            liquidityIndexAtRepayment: 0,
            repaymentFee: 0,
            folId: folId
        });

        validateMinimumCreditOpening(state, sol.getCredit());
        state._fixed.loans.push(sol);
        uint256 solId = state._fixed.loans.length - 1;

        FixedLoan storage exiter = state._fixed.loans[exiterId];
        exiter.faceValueExited += faceValue;
        validateMinimumCredit(state, exiter.getCredit());

        emit Events.CreateFixedLoan(solId, lender, borrower, exiterId, folId, faceValue, fol.dueDate);
    }

    function getFOL(State storage state, FixedLoan storage self) public view returns (FixedLoan storage) {
        return self.isFOL() ? self : state._fixed.loans[self.folId];
    }

    function getFOLId(State storage state, uint256 loanId) public view returns (uint256) {
        FixedLoan storage loan = state._fixed.loans[loanId];
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

    function _either(FixedLoanStatus s, FixedLoanStatus[2] memory status) private pure returns (bool) {
        return s == status[0] || s == status[1];
    }

    function getFOLAssignedCollateral(State storage state, FixedLoan memory loan) public view returns (uint256) {
        if (!loan.isFOL()) revert Errors.NOT_SUPPORTED();

        uint256 debt = state._fixed.debtToken.balanceOf(loan.borrower);
        uint256 collateral = state._fixed.collateralToken.balanceOf(loan.borrower);
        if (debt > 0) {
            return Math.mulDivDown(collateral, loan.faceValue, debt);
        } else {
            return 0;
        }
    }

    function getProRataAssignedCollateral(State storage state, uint256 loanId) public view returns (uint256) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoan storage fol = getFOL(state, loan);
        uint256 folCollateral = getFOLAssignedCollateral(state, fol);
        return Math.mulDivDown(folCollateral, loan.getCredit(), fol.faceValue);
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state._fixed.collateralToken.balanceOf(account);
        uint256 debt = state._fixed.debtToken.balanceOf(account);
        uint256 debtWad = ConversionLibrary.amountToWad(debt, state._general.borrowAsset.decimals());
        uint256 price = state._general.priceFeed.getPrice();

        if (debt > 0) {
            return Math.mulDivDown(collateral, price, debtWad);
        } else {
            return type(uint256).max;
        }
    }

    function isLoanSelfLiquidatable(State storage state, uint256 loanId) public view returns (bool) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoanStatus status = getFixedLoanStatus(state, loan);
        // both FOLs and SOLs can be self liquidated
        return (
            isUserLiquidatable(state, loan.borrower)
                && _either(status, [FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE])
        );
    }

    function isLoanLiquidatable(State storage state, uint256 loanId) public view returns (bool) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoanStatus status = getFixedLoanStatus(state, loan);
        // only FOLs can be liquidated
        return loan.isFOL()
        // case 1: if the user is liquidatable, only active/overdue FOLs can be liquidated
        && (
            (
                isUserLiquidatable(state, loan.borrower)
                    && _either(status, [FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE])
            )
            // case 2: overdue loans can always be liquidated regardless of the user's CR
            || status == FixedLoanStatus.OVERDUE
        );
    }

    function isUserLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state._fixed.crLiquidation;
    }

    function validateUserIsNotBelowRiskCR(State storage state, address account) external view {
        uint256 riskCR = Math.max(
            state._fixed.crOpening,
            state._fixed.users[account].borrowOffer.riskCR // 0 by default, or user-defined if BorrowAsLimitOrder has been placed
        );
        if (collateralRatio(state, account) < riskCR) {
            revert Errors.COLLATERAL_RATIO_BELOW_RISK_COLLATERAL_RATIO(account, collateralRatio(state, account), riskCR);
        }
    }

    function getMinimumCollateralOpening(State storage state, uint256 faceValue) public view returns (uint256) {
        uint256 faceValueWad = ConversionLibrary.amountToWad(faceValue, state._general.borrowAsset.decimals());
        return Math.mulDivUp(faceValueWad, state._fixed.crOpening, state._general.priceFeed.getPrice());
    }
}
