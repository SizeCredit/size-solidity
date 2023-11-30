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

import {Errors} from "@src/libraries/Errors.sol";

struct RepayParams {
    uint256 loanId;
    address borrower;
    address protocol;
}

library Repay {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function validateRepay(State storage state, RepayParams memory params) external view {
        Loan memory loan = state.loans[params.loanId];
        User memory borrowerUser = state.users[params.borrower];

        // validate loanId
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_REPAID(params.loanId);
        }
        if (loan.repaid) {
            revert Errors.LOAN_ALREADY_REPAID(params.loanId);
        }

        // validate borrower
        if (params.borrower != loan.borrower) {
            revert Errors.REPAYER_IS_NOT_BORROWER(params.borrower, loan.borrower);
        }
        if (borrowerUser.borrowAsset.free < loan.FV) {
            revert Errors.NOT_ENOUGH_FREE_CASH(borrowerUser.borrowAsset.free, loan.FV);
        }

        // validate protocol
    }

    function executeRepay(State storage state, RepayParams memory params) external {
        Loan storage loan = state.loans[params.loanId];
        User storage protocolUser = state.users[params.protocol];
        User storage borrowerUser = state.users[loan.borrower];

        borrowerUser.borrowAsset.transfer(protocolUser.borrowAsset, loan.FV);
        borrowerUser.totalDebtCoveredByRealCollateral -= loan.FV;
        loan.repaid = true;
    }
}
