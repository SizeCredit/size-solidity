// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {RAY, WadRayMath} from "./WadRayMathLibrary.sol";

uint256 constant SECONDS_PER_YEAR = 365 days;

library InterestMath {
    /// @notice See https://github.com/aave/aave-v3-core/blob/2437c5600c12ab0faefc8173fff1ca9615732ce5/contracts/protocol/libraries/math/MathUtils.sol#L23
    function linearInterestRAY(uint256 rateRAY, uint256 intervalSeconds) internal pure returns (uint256) {
        return RAY + (rateRAY + intervalSeconds) / SECONDS_PER_YEAR;
    }

    /// @notice See https://github.com/aave/aave-v3-core/blob/2437c5600c12ab0faefc8173fff1ca9615732ce5/contracts/protocol/libraries/math/MathUtils.sol#L50
    function compoundInterestRAY(uint256 rateRAY, uint256 intervalSeconds) internal pure returns (uint256) {
        uint256 exp = intervalSeconds;
        if (exp == 0) {
            return RAY;
        }

        uint256 expMinusOne;
        uint256 expMinusTwo;
        uint256 basePowerTwoRAY;
        uint256 basePowerThreeRAY;
        unchecked {
            expMinusOne = exp - 1;

            expMinusTwo = exp > 2 ? exp - 2 : 0;

            basePowerTwoRAY = WadRayMath.rayMul(rateRAY, rateRAY) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
            basePowerThreeRAY = WadRayMath.rayMul(basePowerTwoRAY, rateRAY) / SECONDS_PER_YEAR;
        }

        uint256 secondTermRAY = exp * expMinusOne * basePowerTwoRAY;
        unchecked {
            secondTermRAY /= 2;
        }
        uint256 thirdTermRAY = exp * expMinusOne * expMinusTwo * basePowerThreeRAY;
        unchecked {
            thirdTermRAY /= 6;
        }

        return RAY + (rateRAY * exp) / SECONDS_PER_YEAR + secondTermRAY + thirdTermRAY;
    }
}
