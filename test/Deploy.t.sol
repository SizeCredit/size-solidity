// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Deployment, Parameter} from "@script/BaseScript.sol";
import {DeployScript} from "@script/Deploy.s.sol";
import {Test} from "forge-std/Test.sol";

contract DeployScriptTest is Test {
    DeployScript deployScript;

    function testFork_Deploy_deploy() public {
        deployScript = new DeployScript();

        (Deployment[] memory deployments, Parameter[] memory parameters) = deployScript.run();

        assertGt(deployments.length, 0);
        assertGt(parameters.length, 0);
    }
}
