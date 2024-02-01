// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {CollateralToken} from "@src/token/CollateralToken.sol";
import {CollateralToken} from "@src/token/CollateralToken.sol";

import {Addresses} from "./Addresses.sol";
import {BaseScript, Deployment} from "./BaseScript.sol";
import {Deploy} from "@test/Deploy.sol";

contract DeployScript is BaseScript, Addresses, Deploy {
    function setUp() public {}

    function run() public broadcast {
        console.log("[Size v2] deploying...");
        uint256 deployerPk = setupLocalhostEnv(0);
        address deployer = vm.addr(deployerPk);
        bool mockVariablePool = vm.envOr("MOCK_VARIABLE_POOL", false);

        console.log("[Size v2] chain\t", chainName);
        console.log("[Size v2] owner\t", deployer);

        if (mockVariablePool) {
            setupChainMockVariablePool(deployer, addresses(chainName).weth, addresses(chainName).usdc);
        } else {
            setupChain(
                deployer, addresses(chainName).variablePool, addresses(chainName).weth, addresses(chainName).usdc
            );
        }

        deployments.push(Deployment({name: "implementation", addr: address(size)}));
        deployments.push(Deployment({name: "proxy", addr: address(proxy)}));
        deployments.push(Deployment({name: "priceFeed", addr: address(priceFeed)}));
        deployments.push(Deployment({name: "variablePool", addr: address(variablePool)}));

        console.log("[Size v2] deployed\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            console.log("[Size v2] ", deployments[i].name, "\t", address(deployments[i].addr));
        }

        exportDeployments();

        console.log("[Size v2] done");
    }
}
