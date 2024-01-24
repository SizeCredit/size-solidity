// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {Math} from "@src/libraries/MathLibrary.sol";
import {InterestMath, SECONDS_PER_YEAR} from "@src/libraries/variable/InterestMath.sol";
import {WadRayMath} from "@src/libraries/variable/WadRayMathLibrary.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

library VariableLibrary {
    function getSlope2(State storage state) internal view returns (uint256) {
        return Math.mulDivDown(
            state._variable.maxRate - state._variable.minRate, PERCENT, PERCENT - state._variable.optimalUR
        );
    }

    function getOptimalIR(State storage state) internal view returns (uint256) {
        return state._variable.minRate + Math.mulDivDown(state._variable.slope, state._variable.optimalUR, PERCENT);
    }

    function getBorrowAPR(State storage state, uint256 ur) internal view returns (uint256) {
        if (ur < state._variable.optimalUR) {
            return state._variable.minRate + Math.mulDivDown(state._variable.slope, ur, PERCENT);
        } else {
            return getOptimalIR(state) + Math.mulDivDown(getSlope2(state), (ur - state._variable.optimalUR), PERCENT);
        }
    }

    function getSupplyAPR(State storage state, uint256 ur) internal view returns (uint256) {
        uint256 borrowAPR = getBorrowAPR(state, ur);
        return
            Math.mulDivDown(borrowAPR, Math.mulDivDown(ur, (PERCENT - state._variable.reserveFactor), PERCENT), PERCENT);
    }

    function getUR(State storage state) internal view returns (uint256) {
        // @audit Should this be debt.totalSupply() / borrow.totalSupply() ?
        uint256 collateral = state._variable.collateralToken.totalSupply();
        uint256 borrow = state._variable.scaledBorrowToken.totalSupply();
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
        uint256 interval = block.timestamp - state._variable.lastUpdate;
        if (interval == 0) {
            return;
        }

        if (state._variable.indexSupplyRAY > 0) {
            uint256 interestRAY = InterestMath.linearInterestRAY(state._variable.indexSupplyRAY, interval);
            state._variable.indexSupplyRAY = WadRayMath.rayMul(interestRAY, state._variable.indexSupplyRAY);
        }

        if (state._variable.indexBorrowRAY > 0) {
            uint256 interestRAY = InterestMath.compoundInterestRAY(state._variable.indexBorrowRAY, interval);
            state._variable.indexBorrowRAY = WadRayMath.rayMul(interestRAY, state._variable.indexBorrowRAY);
        }

        state._variable.lastUpdate = block.timestamp;
    }

    function collateralRatio(State storage state, address account) public view returns (uint256) {
        // TODO this equation seems incorrect, debt should grow with interest
        uint256 collateral = state._variable.collateralToken.balanceOf(account);
        uint256 debt = state._variable.scaledDebtToken.balanceOf(account);
        uint256 price = state._general.priceFeed.getPrice();

        if (debt > 0) {
            return Math.mulDivDown(collateral, price, debt);
        } else {
            return type(uint256).max;
        }
    }

    function isLiquidatable(State storage state, address account) public view returns (bool) {
        return collateralRatio(state, account) < state._variable.minimumCollateralRatio;
    }

    function validateUserIsNotLiquidatableVariable(State storage state, address account) external view {
        if (isLiquidatable(state, account)) {
            revert Errors.USER_IS_LIQUIDATABLE(account, collateralRatio(state, account));
        }
    }

    function getReserveNormalizedIncomeRAY(State storage state) internal view returns (uint256) {
        uint256 interval = block.timestamp - state._variable.lastUpdate;
        if (interval == 0) {
            return state._variable.indexBorrowRAY;
        } else {
            uint256 interestRAY = InterestMath.compoundInterestRAY(state._variable.indexBorrowRAY, interval);
            return WadRayMath.rayMul(interestRAY, state._variable.indexBorrowRAY);
        }
    }

    function updateInterestRates(State storage state) internal {
        // TODO
    }
}
