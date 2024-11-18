// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SizeFactory} from "@src/v1.5/SizeFactory.sol";
import {console2 as console} from "forge-std/Script.sol";

import {BaseScript, Deployment, Parameter} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {NetworkConfiguration, Networks} from "@script/Networks.sol";

contract DeploySizeFactoryScript is BaseScript, Networks, Deploy {
    address deployer;
    address owner;
    string networkConfiguration;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        owner = vm.envOr("OWNER", address(0));
        networkConfiguration = vm.envOr("NETWORK_CONFIGURATION", TEST_NETWORK_CONFIGURATION);
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[SizeFactory v1.5] deploying...");

        console.log("[SizeFactory v1.5] networkConfiguration", networkConfiguration);
        console.log("[SizeFactory v1.5] deployer", deployer);
        console.log("[SizeFactory v1.5] owner", owner);

        SizeFactory implementation = new SizeFactory();
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), abi.encodeCall(SizeFactory.initialize, (owner)));

        deployments.push(Deployment({name: "SizeFactory-implementation", addr: address(implementation)}));
        deployments.push(Deployment({name: "SizeFactory-proxy", addr: address(proxy)}));
        parameters.push(Parameter({key: "owner", value: Strings.toHexString(owner)}));

        console.log("[SizeFactory v1.5] deployed\n");

        for (uint256 i = 0; i < deployments.length; i++) {
            console.log("[SizeFactory v1.5] Deployment: ", deployments[i].name, "\t", address(deployments[i].addr));
        }
        for (uint256 i = 0; i < parameters.length; i++) {
            console.log("[SizeFactory v1.5] Parameter:  ", parameters[i].key, "\t", parameters[i].value);
        }

        exportDeployments(networkConfiguration);

        console.log("[SizeFactory v1.5] done");
    }
}
