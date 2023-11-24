// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import "@src/Errors.sol";

struct ClaimParams {
    uint256 loanId;
    address lender;
    address protocol;
}

library Claim {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function validateClaim(State storage state, ClaimParams memory params) external view {
        Loan memory loan = state.loans[params.loanId];

        // validate loanId
        if (!loan.isRepaid(state.loans)) {
            revert ERROR_LOAN_NOT_REPAID(params.loanId);
        }
        if (loan.claimed) {
            revert ERROR_LOAN_ALREADY_CLAIMED(params.loanId);
        }
        if (params.lender != loan.lender) {
            revert ERROR_CLAIMER_IS_NOT_LENDER(params.lender, loan.lender);
        }
    }

    function executeClaim(State storage state, ClaimParams memory params) external {
        Loan storage loan = state.loans[params.loanId];
        User storage protocolUser = state.users[params.protocol];
        User storage lenderUser = state.users[loan.lender];

        protocolUser.cash.transfer(lenderUser.cash, loan.FV);
        loan.claimed = true;
    }
}
