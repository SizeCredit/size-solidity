// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";

import {Addresses} from "./Addresses.sol";
import {BaseScript, Deployment, Parameter} from "./BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";

contract DeployScript is BaseScript, Addresses, Deploy {
    bool mockContracts;
    address deployer;
    address owner;
    address sizeVariablePoolPool;
    address sizeVariablePoolAaveOracle;
    string chainName;

    function setUp() public {}

    modifier parseEnv() {
        mockContracts = vm.envOr("MOCK_CONTRACTS", true);
        deployer = vm.addr(vm.envOr("DEPLOYER_PRIVATE_KEY", vm.deriveKey(TEST_MNEMONIC, 0)));
        owner = vm.envOr("OWNER", address(0));
        sizeVariablePoolPool = vm.envOr("SIZE_VARIABLE_POOL_POOL", address(0));
        sizeVariablePoolAaveOracle = vm.envOr("SIZE_VARIABLE_POOL_AAVE_ORACLE", address(0));
        chainName = vm.envOr("CHAIN_NAME", TEST_CHAIN_NAME);
        _;
    }

    function run() public parseEnv broadcast returns (Deployment[] memory, Parameter[] memory) {
        console.log("[Size v2] deploying...");

        console.log("[Size v2] chain\t", chainName);
        console.log("[Size v2] owner\t", deployer);

        address weth = addresses(chainName).weth;
        address usdc = addresses(chainName).usdc;

        if (mockContracts) {
            setupChainWithMocks(deployer, weth, usdc);
            console.log("[Size v2] using MOCK contracts");
        } else {
            setupChain(owner, weth, usdc, sizeVariablePoolPool, sizeVariablePoolAaveOracle);
            console.log("[Size v2] using REAL contracts");
        }

        deployments.push(Deployment({name: "Size-implementation", addr: address(size)}));
        deployments.push(Deployment({name: "Size-proxy", addr: address(proxy)}));
        deployments.push(Deployment({name: "PriceFeed", addr: address(priceFeed)}));
        deployments.push(Deployment({name: "VariablePoolBorrowRateFeed", addr: address(variablePoolBorrowRateFeed)}));
        deployments.push(Deployment({name: "VariablePool", addr: address(variablePool)}));
        parameters.push(Parameter({key: "owner", value: Strings.toHexString(deployer)}));
        parameters.push(Parameter({key: "usdc", value: Strings.toHexString(usdc)}));
        parameters.push(Parameter({key: "weth", value: Strings.toHexString(weth)}));
        parameters.push(Parameter({key: "sizeVariablePoolPool", value: Strings.toHexString(sizeVariablePoolPool)}));
        parameters.push(
            Parameter({key: "sizeVariablePoolAaveOracle", value: Strings.toHexString(sizeVariablePoolAaveOracle)})
        );

        console.log("[Size v2] deployed\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            console.log("[Size v2] Deployment: ", deployments[i].name, "\t", address(deployments[i].addr));
        }
        for (uint256 i = 0; i < parameters.length; i++) {
            console.log("[Size v2] Parameter:  ", parameters[i].key, "\t", parameters[i].value);
        }

        exportDeployments();

        console.log("[Size v2] done");

        return (deployments, parameters);
    }
}
