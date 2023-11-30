// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {SizeStorage} from "@src/SizeStorage.sol";
import {UserLibrary, User} from "@src/libraries/UserLibrary.sol";
import {Loan} from "@src/libraries/LoanLibrary.sol";
import {OfferLibrary, BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {LoanLibrary, LoanStatus, Loan} from "@src/libraries/LoanLibrary.sol";
import {RealCollateralLibrary, RealCollateral} from "@src/libraries/RealCollateralLibrary.sol";
import {SizeView} from "@src/SizeView.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

struct LiquidateLoanParams {
    uint256 loanId;
    address liquidator;
    address protocol;
}

library LiquidateLoan {
    using UserLibrary for User;
    using LoanLibrary for Loan;
    using RealCollateralLibrary for RealCollateral;

    function _isLiquidatable(State storage state, address account) internal view returns (bool) {
        return state.users[account].isLiquidatable(state.priceFeed.getPrice(), state.CRLiquidation);
    }

    function _getAssignedCollateral(State storage state, Loan memory loan) internal view returns (uint256) {
        return state.users[loan.borrower].getAssignedCollateral(loan.FV);
    }

    function validateUserIsNotLiquidatable(State storage state, address account) external view {
        if (_isLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(
                account, state.users[account].collateralRatio(state.priceFeed.getPrice())
            );
        }
    }

    function validateLiquidateLoan(State storage state, LiquidateLoanParams memory params) external view {
        Loan memory loan = state.loans[params.loanId];
        uint256 assignedCollateral = _getAssignedCollateral(state, loan);
        uint256 amountCollateralDebtCoverage = loan.getDebt() * 1e18 / state.priceFeed.getPrice();

        // validate loanId
        if (!_isLiquidatable(state, loan.borrower)) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(params.loanId);
        }
        if (!loan.isFOL()) {
            revert Errors.ONLY_FOL_CAN_BE_LIQUIDATED(params.loanId);
        }
        // @audit is this reachable?
        if (loan.either(state.loans, [LoanStatus.REPAID, LoanStatus.CLAIMED])) {
            revert Errors.LOAN_NOT_LIQUIDATABLE(params.loanId);
        }
        if (assignedCollateral < amountCollateralDebtCoverage) {
            revert Errors.LIQUIDATION_AT_LOSS(params.loanId);
        }

        // validate liquidator

        // validate protocol
    }

    function executeLiquidateLoan(State storage state, LiquidateLoanParams memory params) external returns (uint256) {
        Loan storage loan = state.loans[params.loanId];
        User storage borrowerUser = state.users[loan.borrower];
        User storage liquidatorUser = state.users[params.liquidator];
        User storage protocolUser = state.users[params.protocol];

        uint256 price = state.priceFeed.getPrice();

        uint256 assignedCollateral = _getAssignedCollateral(state, loan);
        uint256 debtUSDC = loan.getDebt();
        uint256 debtCollateral = debtUSDC * 1e18 / price;
        uint256 collateralRemainder = assignedCollateral - debtCollateral;

        uint256 collateralRemainderToLiquidator =
            collateralRemainder * state.collateralPercentagePremiumToLiquidator / PERCENT;
        uint256 collateralRemainderToBorrower =
            collateralRemainder * state.collateralPercentagePremiumToBorrower / PERCENT;
        uint256 collateralRemainderToProtocol =
            collateralRemainder - collateralRemainderToLiquidator - collateralRemainderToBorrower;

        borrowerUser.collateralAsset.transfer(protocolUser.collateralAsset, collateralRemainderToProtocol);
        borrowerUser.collateralAsset.transfer(
            liquidatorUser.collateralAsset, collateralRemainderToLiquidator + debtCollateral
        );
        liquidatorUser.borrowAsset.transfer(protocolUser.borrowAsset, debtUSDC);

        state.liquidationProfitETH += collateralRemainderToProtocol;

        return debtCollateral + collateralRemainderToLiquidator;
    }
}
