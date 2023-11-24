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

struct ClaimParams {
    uint256 loanId;
    address lender;
    address protocol;
}

abstract contract SizeClaim is SizeStorage, SizeView, ISize {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _validateClaim(ClaimParams memory params) internal view {
        Loan memory loan = loans[params.loanId];

        // validate loanId
        if (!loan.isRepaid(loans)) {
            revert ERROR_LOAN_NOT_REPAID(params.loanId);
        }
        if (loan.claimed) {
            revert ERROR_LOAN_ALREADY_CLAIMED(params.loanId);
        }
        if (params.lender != loan.lender) {
            revert ERROR_CLAIMER_IS_NOT_LENDER(params.lender, loan.lender);
        }
    }

    function _executeClaim(ClaimParams memory params) internal {
        Loan storage loan = loans[params.loanId];
        User storage protocolUser = users[params.protocol];
        User storage lenderUser = users[loan.lender];

        protocolUser.cash.transfer(lenderUser.cash, loan.FV);
        loan.claimed = true;
    }
}
