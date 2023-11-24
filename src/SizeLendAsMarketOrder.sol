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

struct LendAsMarketOrderParams {
    address lender;
    address borrower;
    uint256 dueDate;
    uint256 amount;
}

abstract contract SizeLendAsMarketOrder is SizeStorage, SizeView, ISize {
    function _validateLendAsMarketOrder(LendAsMarketOrderParams memory params) internal view {
        BorrowOffer memory borrowOffer = users[params.borrower].borrowOffer;
        User memory lenderUser = users[params.lender];

        // validate lender

        // validate borrower

        // validate dueDate

        // validate amount
        if (params.amount > borrowOffer.maxAmount) {
            revert ERROR_AMOUNT_GREATER_THAN_MAX_AMOUNT(params.amount, borrowOffer.maxAmount);
        }
        if (lenderUser.cash.free < params.amount) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(lenderUser.cash.free, params.amount);
        }
    }

    function _executeLendAsMarketOrder(LendAsMarketOrderParams memory params) internal {}
}
