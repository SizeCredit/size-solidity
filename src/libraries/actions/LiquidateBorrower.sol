// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {Math} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Error} from "@src/libraries/Error.sol";

struct LiquidateBorrowerParams {
    address borrower;
    address liquidator;
}

library LiquidateBorrower {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;
    using UserLibrary for User;

    event LiquidationAtLoss(uint256 amount);

    function _isLiquidatable(State storage state, address account) internal view returns (bool) {
        return state.users[account].isLiquidatable(state.priceFeed.getPrice(), state.CRLiquidation);
    }

    function validateUserIsNotLiquidatable(State storage state, address account) external view {
        if (_isLiquidatable(state, account)) {
            revert Error.USER_IS_LIQUIDATABLE(account, state.users[account].collateralRatio(state.priceFeed.getPrice()));
        }
    }

    function validateLiquidateBorrower(State storage state, LiquidateBorrowerParams memory params) external view {
        User memory borrowerUser = state.users[params.borrower];
        User memory liquidatorUser = state.users[params.liquidator];

        // validate borrower
        if (!_isLiquidatable(state, params.borrower)) {
            revert Error.NOT_LIQUIDATABLE(params.borrower);
        }

        // validate liquidator
        if (liquidatorUser.cash.free < borrowerUser.totDebtCoveredByRealCollateral) {
            revert Error.NOT_ENOUGH_FREE_CASH(liquidatorUser.cash.free, borrowerUser.totDebtCoveredByRealCollateral);
        }
    }

    function executeLiquidateBorrower(State storage state, LiquidateBorrowerParams memory params)
        external
        returns (uint256 actualAmountETH, uint256 targetAmountETH)
    {
        User storage borrowerUser = state.users[params.borrower];
        User storage liquidatorUser = state.users[params.liquidator];

        uint256 amountUSDC = borrowerUser.totDebtCoveredByRealCollateral - borrowerUser.cash.locked;

        targetAmountETH = (amountUSDC * 1e18) / state.priceFeed.getPrice();
        actualAmountETH = Math.min(targetAmountETH, borrowerUser.eth.locked);
        if (actualAmountETH < targetAmountETH) {
            emit LiquidationAtLoss(targetAmountETH - actualAmountETH);
        }

        // _liquidationSwap(liquidatorUser, borrowerUser, amountUSDC, actualAmountETH);
        liquidatorUser.cash.transfer(borrowerUser.cash, amountUSDC);
        borrowerUser.cash.lock(amountUSDC);
        borrowerUser.eth.unlock(actualAmountETH);
        borrowerUser.eth.transfer(liquidatorUser.eth, actualAmountETH);

        borrowerUser.totDebtCoveredByRealCollateral = 0;
    }
}
