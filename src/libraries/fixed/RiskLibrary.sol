// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {State} from "@src/SizeStorage.sol";

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/Math.sol";
import {FixedLoan, FixedLoanLibrary, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

library RiskLibrary {
    using FixedLoanLibrary for State;
    using FixedLoanLibrary for FixedLoan;
    using FixedLoanLibrary for FixedLoanStatus;

    function validateMinimumCredit(State storage state, uint256 credit) public view {
        if (0 < credit && credit < state._fixed.minimumCreditBorrowAsset) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT(credit, state._fixed.minimumCreditBorrowAsset);
        }
    }

    function validateMinimumCreditOpening(State storage state, uint256 credit) public view {
        if (credit < state._fixed.minimumCreditBorrowAsset) {
            revert Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING(credit, state._fixed.minimumCreditBorrowAsset);
        }
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        uint256 collateral = state._fixed.collateralToken.balanceOf(account);
        uint256 debt = state._fixed.debtToken.balanceOf(account);
        uint256 debtWad = ConversionLibrary.amountToWad(debt, state._general.underlyingBorrowToken.decimals());
        uint256 price = state._general.priceFeed.getPrice();

        if (debt > 0) {
            return Math.mulDivDown(collateral, price, debtWad);
        } else {
            return type(uint256).max;
        }
    }

    function isLoanSelfLiquidatable(State storage state, uint256 loanId) public view returns (bool) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoanStatus status = state.getFixedLoanStatus(loan);
        // both FOLs and SOLs can be self liquidated
        return (
            isUserLiquidatable(state, loan.generic.borrower)
                && status.either([FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE])
        );
    }

    function isLoanLiquidatable(State storage state, uint256 loanId) public view returns (bool) {
        FixedLoan storage loan = state._fixed.loans[loanId];
        FixedLoanStatus status = state.getFixedLoanStatus(loan);
        // only FOLs can be liquidated
        return loan.isFOL()
        // case 1: if the user is liquidatable, only active/overdue FOLs can be liquidated
        && (
            (
                isUserLiquidatable(state, loan.generic.borrower)
                    && status.either([FixedLoanStatus.ACTIVE, FixedLoanStatus.OVERDUE])
            )
            // case 2: overdue loans can always be liquidated regardless of the user's CR
            || status == FixedLoanStatus.OVERDUE
        );
    }

    function isUserLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state._fixed.crLiquidation;
    }

    function validateUserIsNotLiquidatable(State storage state, address account) external view {
        if (isUserLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(account, collateralRatio(state, account));
        }
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
        uint256 faceValueWad = ConversionLibrary.amountToWad(faceValue, state._general.underlyingBorrowToken.decimals());
        return Math.mulDivUp(faceValueWad, state._fixed.crOpening, state._general.priceFeed.getPrice());
    }
}
