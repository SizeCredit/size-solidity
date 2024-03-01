// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {ForkTest} from "@test/ForkTest.sol";

contract DeployScriptTest is ForkTest {
    function testFork_Deploy_check_variablePool_is_configured() public {
        assertTrue(address(size.data().variablePool) != address(0));
        assertEq(address(size.data().variablePool), address(variablePool));
        assertEq(size.data().variablePool.getReserveNormalizedIncome(address(usdc)), WadRayMath.RAY);
    }
}
