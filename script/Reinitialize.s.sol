// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";
import {ISize} from "@src/interfaces/ISize.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {Networks} from "@script/Networks.sol";

contract ReinitializeScript is BaseScript, Networks, Deploy {
    address deployer;
    string networkConfiguration;
    address borrowATokenV1_5;
    address[] users;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        networkConfiguration = vm.envOr("NETWORK_CONFIGURATION", TEST_NETWORK_CONFIGURATION);
        borrowATokenV1_5 = vm.envAddress("BORROW_A_TOKEN_V1_5");
        users = vm.envAddress("USERS", ",");
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[Size v1.5] reinitializing...\n");

        console.log("[Size v1.5] networkConfiguration", networkConfiguration);
        console.log("[Size v1.5] deployer", deployer);

        (ISize proxy,,) = importDeployments(networkConfiguration);

        Size(address(proxy)).reinitialize(borrowATokenV1_5, users);

        console.log("[Size v1.5] done");
    }
}