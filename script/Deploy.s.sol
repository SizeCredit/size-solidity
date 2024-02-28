// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {console2 as console} from "forge-std/Script.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Size} from "@src/Size.sol";

import {Addresses} from "./Addresses.sol";
import {BaseScript, Deployment, Parameter} from "./BaseScript.sol";
import {Deploy} from "@test/Deploy.sol";

contract DeployScript is BaseScript, Addresses, Deploy {
    function setUp() public {}

    function run() public broadcast {
        console.log("[Size v2] deploying...");
        uint256 deployerPk = setupLocalhostEnv(0);
        address deployer = vm.addr(deployerPk);
        string memory chainName = vm.envString("CHAIN_NAME");

        console.log("[Size v2] chain\t", chainName);
        console.log("[Size v2] owner\t", deployer);

        address weth = addresses(chainName).weth;
        address usdc = addresses(chainName).usdc;

        setupChainMocks(deployer, weth, usdc);

        deployments.push(Deployment({name: "implementation", addr: address(size)}));
        deployments.push(Deployment({name: "proxy", addr: address(proxy)}));
        deployments.push(Deployment({name: "priceFeed", addr: address(priceFeed)}));
        deployments.push(Deployment({name: "marketBorrowRateFeed", addr: address(marketBorrowRateFeed)}));
        deployments.push(Deployment({name: "variablePool", addr: address(variablePool)}));
        parameters.push(Parameter({key: "owner", value: Strings.toHexString(deployer)}));
        parameters.push(Parameter({key: "usdc", value: Strings.toHexString(usdc)}));
        parameters.push(Parameter({key: "weth", value: Strings.toHexString(weth)}));

        console.log("[Size v2] deployed\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            console.log("[Size v2] Deployment: ", deployments[i].name, "\t", address(deployments[i].addr));
        }
        for (uint256 i = 0; i < parameters.length; i++) {
            console.log("[Size v2] Parameter:  ", parameters[i].key, "\t", parameters[i].value);
        }

        export();

        console.log("[Size v2] done");
    }
}
