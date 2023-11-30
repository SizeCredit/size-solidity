// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct LendAsLimitOrderParams {
    address lender;
    uint256 maxAmount;
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

library LendAsLimitOrder {
    function validateLendAsLimitOrder(State storage, LendAsLimitOrderParams memory params) external view {
        // validate params.borrower
        // N/A

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate maxDueDate
        if (params.maxDueDate == 0) {
            revert Errors.NULL_MAX_DUE_DATE();
        }
        if (params.maxDueDate < block.timestamp) {
            revert Errors.PAST_MAX_DUE_DATE(params.maxDueDate);
        }

        // validate params.curveRelativeTime
        if (params.curveRelativeTime.timeBuckets.length == 0 || params.curveRelativeTime.rates.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (params.curveRelativeTime.timeBuckets.length != params.curveRelativeTime.rates.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
    }

    function executeLendAsLimitOrder(State storage state, LendAsLimitOrderParams memory params) external {
        state.users[params.lender].loanOffer = LoanOffer({
            maxAmount: params.maxAmount,
            maxDueDate: params.maxDueDate,
            curveRelativeTime: params.curveRelativeTime
        });
    }
}
