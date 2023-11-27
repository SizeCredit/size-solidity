// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, LoanStatus, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {Math, PERCENT} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {LiquidateBorrower} from "@src/libraries/actions/LiquidateBorrower.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Error} from "@src/libraries/Error.sol";

struct LiquidateLoanParams {
    uint256 loanId;
    address liquidator;
}

library LiquidateLoan {
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _getAssignedCollateral(State storage state, uint256 loanId) internal view returns (uint256) {
        Loan memory loan = state.loans[loanId];
        User memory borrower = state.users[loan.borrower];
        if (borrower.totDebtCoveredByRealCollateral == 0) {
            return 0;
        } else {
            return borrower.eth.free * loan.FV / borrower.totDebtCoveredByRealCollateral;
        }
    }

    function _liquidationSwap(
        User storage liquidatorUser,
        User storage borrowerUser,
        uint256 amountUSDC,
        uint256 amountETH
    ) internal {
        // @audit liquidator cash is transferred to the protocol as we don't want dead money
        liquidatorUser.cash.transfer(borrowerUser.cash, amountUSDC);
        borrowerUser.eth.transfer(liquidatorUser.eth, amountETH);
    }

    function validateLiquidateLoan(State storage state, LiquidateLoanParams memory params) external view {
        Loan memory loan = state.loans[params.loanId];
        uint256 assignedCollateral = _getAssignedCollateral(state, params.loanId);
        uint256 amountCollateralDebtCoverage = loan.getDebt(true, state.priceFeed.getPrice());

        // validate loanId
        if (!loan.isFOL()) {
            revert Error.ONLY_FOL_CAN_BE_LIQUIDATED(params.loanId);
        }
        if (!LiquidateBorrower._isLiquidatable(state, loan.borrower)) {
            revert Error.LOAN_NOT_LIQUIDATABLE(params.loanId);
        }
        if (loan.getLoanStatus(state.loans) != LoanStatus.OVERDUE) {
            revert Error.LOAN_NOT_LIQUIDATABLE(params.loanId);
        }
        if (assignedCollateral < amountCollateralDebtCoverage) {
            revert Error.LIQUIDATION_AT_LOSS(params.loanId);
        }
    }

    function executeLiquidateLoan(State storage state, LiquidateLoanParams memory params) external returns (uint256) {
        // solidity
        Loan storage loan = state.loans[params.loanId];
        User storage borrowerUser = state.users[loan.borrower];
        User storage liquidatorUser = state.users[params.liquidator];
        uint256 price = state.priceFeed.getPrice();

        uint256 assignedCollateral = _getAssignedCollateral(state, params.loanId);
        uint256 amountCollateralDebtCoverage = loan.getDebt(true, price);
        uint256 collateralRemainder = assignedCollateral - amountCollateralDebtCoverage;

        uint256 amountCollateralToLiquidator =
            collateralRemainder * state.collateralPercentagePremiumToLiquidator / PERCENT;
        uint256 amountCollateralToBorrower = collateralRemainder * state.collateralPercentagePremiumToBorrower / PERCENT;
        uint256 amountCollateralToProtocol =
            collateralRemainder - amountCollateralToLiquidator - amountCollateralToBorrower;

        state.liquidationProfitETH += amountCollateralToProtocol;

        uint256 amountUSDC = loan.getDebt(false, price);
        uint256 amountETH = amountCollateralDebtCoverage + amountCollateralToLiquidator;

        _liquidationSwap(liquidatorUser, borrowerUser, amountUSDC, amountETH);

        liquidatorUser.eth.transfer(borrowerUser.eth, amountCollateralToBorrower - amountCollateralDebtCoverage);
        borrowerUser.eth.transfer(liquidatorUser.eth, amountCollateralToLiquidator);

        return amountCollateralDebtCoverage + amountCollateralToLiquidator;
    }
}
