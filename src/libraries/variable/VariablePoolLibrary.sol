// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {InterestMath, SECONDS_PER_YEAR} from "@src/libraries/InterestMath.sol";
import {Math} from "@src/libraries/MathLibrary.sol";
import {WadRayMath} from "@src/libraries/WadRayMathLibrary.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

library VariablePoolLibrary {
    function getSlope2(State storage state) internal view returns (uint256) {
        return Math.mulDivDown(state.v.maxRate - state.v.minRate, PERCENT, PERCENT - state.v.optimalUR);
    }

    function getOptimalIR(State storage state) internal view returns (uint256) {
        return state.v.minRate + Math.mulDivDown(state.v.slope, state.v.optimalUR, PERCENT);
    }

    function getBorrowAPR(State storage state, uint256 ur) internal view returns (uint256) {
        if (ur < state.v.optimalUR) {
            return state.v.minRate + Math.mulDivDown(state.v.slope, ur, PERCENT);
        } else {
            return getOptimalIR(state) + Math.mulDivDown(getSlope2(state), (ur - state.v.optimalUR), PERCENT);
        }
    }

    function getSupplyAPR(State storage state, uint256 ur) internal view returns (uint256) {
        uint256 borrowAPR = getBorrowAPR(state, ur);
        return Math.mulDivDown(borrowAPR, Math.mulDivDown(ur, (PERCENT - state.v.reserveFactor), PERCENT), PERCENT);
    }

    function getUR(State storage state) internal view returns (uint256) {
        // @audit Should this be debt.totalSupply() / borrow.totalSupply() ?
        uint256 collateral = state.v.collateralToken.totalSupply();
        uint256 borrow = state.v.scaledBorrowToken.totalSupply();
        if (collateral > 0) {
            return Math.mulDivDown(borrow, PERCENT, collateral);
        } else {
            return 0;
        }
    }

    function getBorrowAPR(State storage state) internal view returns (uint256) {
        return getBorrowAPR(state, getUR(state));
    }

    function getSupplyAPR(State storage state) internal view returns (uint256) {
        return getSupplyAPR(state, getUR(state));
    }

    function getPerSecondBorrowIR(State storage state) internal view returns (uint256) {
        return getBorrowAPR(state) / SECONDS_PER_YEAR;
    }

    function getPerSecondSupplyIR(State storage state) internal view returns (uint256) {
        return getSupplyAPR(state) / SECONDS_PER_YEAR;
    }

    function updateLiquidityIndex(State storage state) internal {
        uint256 interval = block.timestamp - state.v.lastUpdate;
        if (interval == 0) {
            return;
        }

        if (state.v.liquidityIndexSupplyRAY > 0) {
            uint256 interestRAY = InterestMath.linearInterestRAY(state.v.liquidityIndexSupplyRAY, interval);
            state.v.liquidityIndexSupplyRAY = WadRayMath.rayMul(interestRAY, state.v.liquidityIndexSupplyRAY);
        }

        if (state.v.liquidityIndexBorrowRAY > 0) {
            uint256 interestRAY = InterestMath.compoundInterestRAY(state.v.liquidityIndexBorrowRAY, interval);
            state.v.liquidityIndexBorrowRAY = WadRayMath.rayMul(interestRAY, state.v.liquidityIndexBorrowRAY);
        }

        state.v.lastUpdate = block.timestamp;
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        // TODO this equation seems incorrect, debt should grow with interest
        uint256 collateral = state.v.collateralToken.balanceOf(account);
        uint256 debt = state.v.scaledDebtToken.balanceOf(account);
        uint256 price = state.g.priceFeed.getPrice();

        if (debt > 0) {
            return Math.mulDivDown(collateral, price, debt);
        } else {
            return type(uint256).max;
        }
    }

    function isLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state.v.minimumCollateralRatio;
    }

    function validateUserIsNotLiquidatableVariable(State storage state, address account) external view {
        if (isLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(account, collateralRatio(state, account));
        }
    }

    function getReserveNormalizedIncome(State storage state) internal view returns (uint256) {
        uint256 interval = block.timestamp - state.v.lastUpdate;
        if (interval == 0) {
            return state.v.liquidityIndexBorrowRAY;
        } else {
            uint256 interestRAY = InterestMath.compoundInterestRAY(state.v.liquidityIndexBorrowRAY, interval);
            return Math.mulDivDown(interestRAY, state.v.liquidityIndexBorrowRAY, PERCENT);
        }
    }

    function updateInterestRates(State storage state) internal {
        // TODO
    }
}
