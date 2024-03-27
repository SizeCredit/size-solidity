// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {Test} from "forge-std/Test.sol";

contract WadRayMathTest is Test {
    function testFuzz_WadRayMath_rayDiv_rayMul_identity(uint256 x, uint256 y) public {
        x = bound(x, 0, type(uint128).max);
        y = bound(y, 1, type(uint128).max);

        uint256 x_div_y = WadRayMath.rayDiv(x, y);
        uint256 x_div_y_mul_y = WadRayMath.rayMul(x_div_y, y);
        assertLe(x_div_y_mul_y, x, "rayMul(rayDiv(x, y), y) should equal x");
    }
}
