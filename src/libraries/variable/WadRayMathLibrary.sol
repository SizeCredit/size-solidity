// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AaveWadRayMath} from "./WadRayMath.sol";
import {Rounding} from "@src/libraries/MathLibrary.sol";

uint256 constant WAD = 1e18;
uint256 constant RAY = 1e27;

library WadRayMath {
    // TODO perform proper rounding
    function rayDivDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return AaveWadRayMath.rayDiv(x, y);
    }

    function rayMulDown(uint256 x, uint256 y) internal pure returns (uint256) {
        return AaveWadRayMath.rayMul(x, y);
    }

    function rayDiv(uint256 x, uint256 y, Rounding) internal pure returns (uint256) {
        return AaveWadRayMath.rayDiv(x, y);
    }

    function rayMul(uint256 x, uint256 y, Rounding) internal pure returns (uint256) {
        return AaveWadRayMath.rayMul(x, y);
    }

    /// @notice Rounds to the nearest RAY
    function rayDiv(uint256 x, uint256 y) internal pure returns (uint256) {
        return AaveWadRayMath.rayDiv(x, y);
    }

    /// @notice Rounds to the nearest RAY
    function rayMul(uint256 x, uint256 y) internal pure returns (uint256) {
        return AaveWadRayMath.rayMul(x, y);
    }
}
