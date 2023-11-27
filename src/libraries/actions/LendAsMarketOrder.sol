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

import {Error} from "@src/libraries/Error.sol";

struct LendAsMarketOrderParams {
    address lender;
    address borrower;
    uint256 dueDate;
    uint256 amount;
}

library LendAsMarketOrder {
    function validateLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) external view {
        BorrowOffer memory borrowOffer = state.users[params.borrower].borrowOffer;
        User memory lenderUser = state.users[params.lender];

        // validate lender

        // validate borrower

        // validate dueDate

        // validate amount
        if (params.amount > borrowOffer.maxAmount) {
            revert Error.AMOUNT_GREATER_THAN_MAX_AMOUNT(params.amount, borrowOffer.maxAmount);
        }
        if (lenderUser.cash.free < params.amount) {
            revert Error.NOT_ENOUGH_FREE_CASH(lenderUser.cash.free, params.amount);
        }
    }

    function executeLendAsMarketOrder(State storage state, LendAsMarketOrderParams memory params) internal {}
}