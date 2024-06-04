// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract WadRayMathTest is BaseTest {
    function testFuzz_WadRayMath_rayDiv_rayMul_identity(uint256 x, uint256 y) public {
        x = bound(x, 0, type(uint128).max);
        y = bound(y, WadRayMath.RAY, WadRayMath.RAY * 2);

        uint256 x_div_y = WadRayMath.rayDiv(x, y);
        uint256 x_div_y_mul_y = WadRayMath.rayMul(x_div_y, y);
        assertEqApprox(x_div_y_mul_y, x, 1, "rayMul(rayDiv(x, y), y) should equal x +- 1");
    }
}
