// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {State} from "@src/SizeStorage.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

struct VariablePoolConfig {
    uint256 minRate;
    uint256 maxRate;
    uint256 slope;
    uint256 turningPoint;
}

struct VariablePoolState {
    uint256 liquidityIndex;
    uint256 totalBorrowed;
}

library VariablePool {
// WIP
/*
    function getUtilizationRatio(State storage state) internal view returns (uint256) {
        uint256 totalBorrowed = state.variablePoolState.totalBorrowed;
        uint256 totalDeposits = state.tokens.borrowAsset.balanceOf(state.vaults.variablePool);

        if (totalDeposits > 0) {
            return FixedPointMathLib.mulDivDown(totalBorrowed, PERCENT, totalDeposits);
        } else {
            return 0;
        }
    }

    function getInterestRate(State storage state) internal view returns (uint256) {
        uint256 utilizationRatio = getUtilizationRatio(state);
        uint256 maxLowSlopeRate = state.variablePoolConfig.minRate
            - FixedPointMathLib.mulDivDown(state.variablePoolConfig.slope, utilizationRatio, PERCENT);

        if (utilizationRatio <= state.variablePoolConfig.turningPoint) {
            return maxLowSlopeRate;
        } else {
            uint256 slopeHigh = FixedPointMathLib.mulDivDown(
                state.variablePoolConfig.maxRate - maxLowSlopeRate,
                PERCENT,
                PERCENT - state.variablePoolConfig.turningPoint
            );
            return maxLowSlopeRate
                + FixedPointMathLib.mulDivDown(
                    slopeHigh, (utilizationRatio - state.variablePoolConfig.turningPoint), PERCENT
                );
        }
    }
*/
}
