// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {PoolMock} from "@test/mocks/PoolMock.sol";
import {console2 as console} from "forge-std/console2.sol";

contract PoolMockScript is BaseTest, BaseScript {
    function run() external broadcast {
        console.log("PoolMock...");
        (,, variablePool,, weth,) = importDeployments();

        PoolMock(address(variablePool)).setLiquidityIndex(address(weth), WadRayMath.RAY);
    }
}
