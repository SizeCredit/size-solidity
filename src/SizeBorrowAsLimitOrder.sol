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

struct BorrowAsLimitOrderParams {
    address borrower;
    uint256 maxAmount;
    YieldCurve curveRelativeTime;
}

abstract contract SizeBorrowAsLimitOrder is SizeStorage, SizeView, ISize {
    function _validateBorrowAsLimitOrder(BorrowAsLimitOrderParams memory params) internal pure {
        // validate params.borrower
        // N/A

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert ERROR_NULL_AMOUNT();
        }

        // validate params.curveRelativeTime
        if (params.curveRelativeTime.timeBuckets.length == 0 || params.curveRelativeTime.rates.length == 0) {
            revert ERROR_NULL_ARRAY();
        }
        if (params.curveRelativeTime.timeBuckets.length != params.curveRelativeTime.rates.length) {
            revert ERROR_ARRAY_LENGTHS_MISMATCH();
        }
    }

    function _borrowAsLimitOrder(BorrowAsLimitOrderParams memory params) internal {
        users[params.borrower].borrowOffer =
            BorrowOffer({maxAmount: params.maxAmount, curveRelativeTime: params.curveRelativeTime});
    }
}
