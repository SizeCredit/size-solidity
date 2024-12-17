// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SizeFactory} from "@src/v1.5/SizeFactory.sol";
import {console} from "forge-std/Script.sol";
import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";

contract UpgradeSizeFactoryScript is BaseScript, Deploy {
    address deployer;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[SizeFactory v1.5] upgrading...");

        SizeFactory implementation = new SizeFactory();

        console.log("[SizeFactory v1.5] implementation", address(implementation));

        console.log("[SizeFactory v1.5] done");
    }
}
