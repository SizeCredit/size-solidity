// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, LoanOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {SizeView} from "./SizeView.sol";
import {PERCENT} from "./libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "./interfaces/ISize.sol";

struct LendAsLimitOrderParams {
    address lender;
    uint256 maxAmount;
    uint256 maxDueDate;
    YieldCurve curveRelativeTime;
}

abstract contract SizeLendAsLimitOrder is SizeStorage, SizeView, ISize {
    function _validateLendAsLimitOrder(LendAsLimitOrderParams memory params) internal view {
        // validate params.borrower
        // N/A

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert ERROR_NULL_AMOUNT();
        }

        // validate maxDueDate
        if (params.maxDueDate == 0) {
            revert ERROR_NULL_MAX_DUE_DATE();
        }
        if (params.maxDueDate < block.timestamp) {
            revert ERROR_PAST_MAX_DUE_DATE(params.maxDueDate);
        }

        // validate params.curveRelativeTime
        if (params.curveRelativeTime.timeBuckets.length == 0 || params.curveRelativeTime.rates.length == 0) {
            revert ERROR_NULL_ARRAY();
        }
        if (params.curveRelativeTime.timeBuckets.length != params.curveRelativeTime.rates.length) {
            revert ERROR_ARRAY_LENGTHS_MISMATCH();
        }
    }

    function _lendAsLimitOrder(LendAsLimitOrderParams memory params) internal {
        users[params.lender].loanOffer = LoanOffer({
            maxAmount: params.maxAmount,
            maxDueDate: params.maxDueDate,
            curveRelativeTime: params.curveRelativeTime
        });
    }
}
