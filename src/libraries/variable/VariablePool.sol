// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {State} from "@src/SizeStorage.sol";
import {Math} from "@src/libraries/MathLibrary.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";
// WIP
/*
    function getUtilizationRatio(State storage state) internal view returns (uint256) {
        uint256 totalBorrowed = state.variablePoolState.totalBorrowed;
        uint256 totalDeposits = state.g.borrowAsset.balanceOf(state.g.variablePool);

        if (totalDeposits > 0) {
            return Math.mulDivDown(totalBorrowed, PERCENT, totalDeposits);
        } else {
            return 0;
        }
    }

    function getInterestRate(State storage state) internal view returns (uint256) {
        uint256 utilizationRatio = getUtilizationRatio(state);
        uint256 maxLowSlopeRate = state.variablePoolConfig.minRate
            - Math.mulDivDown(state.variablePoolConfig.slope, utilizationRatio, PERCENT);

        if (utilizationRatio <= state.variablePoolConfig.turningPoint) {
            return maxLowSlopeRate;
        } else {
            uint256 slopeHigh = Math.mulDivDown(
                state.variablePoolConfig.maxRate - maxLowSlopeRate,
                PERCENT,
                PERCENT - state.variablePoolConfig.turningPoint
            );
            return maxLowSlopeRate
                + Math.mulDivDown(
                    slopeHigh, (utilizationRatio - state.variablePoolConfig.turningPoint), PERCENT
                );
        }
    }
*/
