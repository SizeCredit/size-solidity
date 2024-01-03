// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {PERCENT} from "@src/libraries/MathLibrary.sol";

struct VariablePool {
    uint256 liquidityIndex;
    uint256 totalLentOut;
    uint256 minRate;
    uint256 maxRate;
    uint256 slope;
    uint256 turningPoint;
}

library VariablePoolLibrary {}
