// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {Addresses} from "./Addresses.sol";
import {BaseScript, Deployment, Parameter} from "./BaseScript.sol";
import {Deploy} from "@test/Deploy.sol";

contract DeployScript is BaseScript, Addresses, Deploy {
    function setUp() public {}

    function run() public broadcast returns (Deployment[] memory, Parameter[] memory) {
        console.log("[Size v2] deploying...");
        uint256 deployerPk = vm.envOr("DEPLOYER_PRIVATE_KEY", vm.deriveKey(TEST_MNEMONIC, 0));
        string memory chainName = vm.envOr("CHAIN_NAME", TEST_CHAIN_NAME);

        address deployer = vm.addr(deployerPk);

        console.log("[Size v2] chain\t", chainName);
        console.log("[Size v2] owner\t", deployer);

        address weth = addresses(chainName).weth;
        address usdc = addresses(chainName).usdc;

        setupChainMocks(deployer, weth, usdc);

        deployments.push(Deployment({name: "Size-implementation", addr: address(size)}));
        deployments.push(Deployment({name: "Size-proxy", addr: address(proxy)}));
        deployments.push(Deployment({name: "PriceFeed", addr: address(priceFeed)}));
        deployments.push(Deployment({name: "MarketBorrowRateFeed", addr: address(marketBorrowRateFeed)}));
        deployments.push(Deployment({name: "VariablePool", addr: address(variablePool)}));
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

        return (deployments, parameters);
    }
}
