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

import {State} from "@src/SizeStorage.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct BorrowAsLimitOrderParams {
    address borrower;
    uint256 maxAmount;
    YieldCurve curveRelativeTime;
}

library BorrowAsLimitOrder {
    function validateBorrowAsLimitOrder(State storage, BorrowAsLimitOrderParams memory params) external pure {
        // validate params.borrower
        // N/A

        // validate params.maxAmount
        if (params.maxAmount == 0) {
            revert Errors.NULL_AMOUNT();
        }

        // validate params.curveRelativeTime
        if (params.curveRelativeTime.timeBuckets.length == 0 || params.curveRelativeTime.rates.length == 0) {
            revert Errors.NULL_ARRAY();
        }
        if (params.curveRelativeTime.timeBuckets.length != params.curveRelativeTime.rates.length) {
            revert Errors.ARRAY_LENGTHS_MISMATCH();
        }
    }

    function executeBorrowAsLimitOrder(State storage state, BorrowAsLimitOrderParams memory params) external {
        state.users[params.borrower].borrowOffer =
            BorrowOffer({maxAmount: params.maxAmount, curveRelativeTime: params.curveRelativeTime});
    }
}
