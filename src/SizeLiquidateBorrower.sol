// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "./SizeStorage.sol";
import {User} from "./libraries/UserLibrary.sol";
import {Loan} from "./libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "./libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "./libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "./libraries/RealCollateralLibrary.sol";
import {SizeView} from "./SizeView.sol";
import {Math} from "./libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "./interfaces/ISize.sol";

struct LiquidateBorrowerParams {
    address borrower;
    address liquidator;
}

abstract contract SizeLiquidateBorrower is SizeStorage, SizeView, ISize {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _validateLiquidateBorrower(LiquidateBorrowerParams memory params) internal view {
        User memory borrowerUser = users[params.borrower];
        User memory liquidatorUser = users[params.liquidator];

        // validate borrower
        if (!isLiquidatable(params.borrower)) {
            revert ERROR_NOT_LIQUIDATABLE(params.borrower);
        }

        // validate liquidator
        if (liquidatorUser.cash.free < borrowerUser.totDebtCoveredByRealCollateral) {
            revert ERROR_NOT_ENOUGH_FREE_CASH(liquidatorUser.cash.free, borrowerUser.totDebtCoveredByRealCollateral);
        }
    }

    function _executeLiquidateBorrower(LiquidateBorrowerParams memory params)
        internal
        returns (uint256 actualAmountETH, uint256 targetAmountETH)
    {
        User storage borrowerUser = users[params.borrower];
        User storage liquidatorUser = users[params.liquidator];

        uint256 amountUSDC = borrowerUser.totDebtCoveredByRealCollateral - borrowerUser.cash.locked;

        targetAmountETH = (amountUSDC * 1e18) / priceFeed.getPrice();
        actualAmountETH = Math.min(targetAmountETH, borrowerUser.eth.locked);
        if (actualAmountETH < targetAmountETH) {
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        liquidatorUser.cash.transfer(borrowerUser.cash, amountUSDC);
        borrowerUser.cash.lock(amountUSDC);
        borrowerUser.eth.unlock(actualAmountETH);
        borrowerUser.eth.transfer(liquidatorUser.eth, actualAmountETH);

        borrowerUser.totDebtCoveredByRealCollateral = 0;
    }
}
