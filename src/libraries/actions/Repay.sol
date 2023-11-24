// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import "@src/Errors.sol";

struct RepayParams {
    uint256 loanId;
    uint256 amount;
}

library Repay {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function validateRepay(State storage state, RepayParams memory params) external view {
        Loan memory loan = state.loans[params.loanId];
        User memory borrower = state.users[loan.borrower];

        // validate loanId
        if (!loan.isFOL()) {
            revert ERROR_ONLY_FOL_CAN_BE_REPAID(params.loanId);
        }
        if (loan.repaid) {
            revert ERROR_LOAN_ALREADY_REPAID(params.loanId);
        }

        // validate amount
        if (params.amount < loan.FV) {
            revert ERROR_INVALID_PARTIAL_REPAY_AMOUNT(params.amount, loan.FV);
        }
        if (borrower.cash.free < params.amount) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(borrower.cash.free, params.amount);
        }
    }

    function executeRepay(State storage state, RepayParams memory params) external {
        Loan storage loan = state.loans[params.loanId];
        User storage borrowerUser = state.users[loan.borrower];
        User storage protocolUser = state.users[address(this)];

        borrowerUser.cash.transfer(protocolUser.cash, params.amount);
        borrowerUser.totDebtCoveredByRealCollateral -= loan.FV;
        loan.repaid = true;
    }
}
