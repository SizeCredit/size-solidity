// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {SizeView} from "./SizeView.sol";
import {PERCENT} from "./libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "./interfaces/ISize.sol";

struct RepayParams {
    uint256 loanId;
    uint256 amount;
}

abstract contract SizeRepay is SizeStorage, SizeView, ISize {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _validateRepay(RepayParams memory params) internal view {
        Loan memory loan = loans[params.loanId];
        User memory borrower = users[loan.borrower];

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

    function _executeRepay(RepayParams memory params) internal {
        Loan storage loan = loans[params.loanId];
        User storage borrowerUser = users[loan.borrower];
        User storage protocolUser = users[address(this)];

        borrowerUser.cash.transfer(protocolUser.cash, params.amount);
        borrowerUser.totDebtCoveredByRealCollateral -= loan.FV;
        loan.repaid = true;
    }
}
