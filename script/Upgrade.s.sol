// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/Size.sol";
import {ISize} from "@src/interfaces/ISize.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {Networks} from "@script/Networks.sol";

contract UpgradeScript is BaseScript, Networks, Deploy {
    address deployer;
    string chainName;
    bool shouldUpgrade;

    function setUp() public {}

    modifier parseEnv() {
        deployer = vm.envOr("DEPLOYER_ADDRESS", vm.addr(vm.deriveKey(TEST_MNEMONIC, 0)));
        chainName = vm.envOr("CHAIN_NAME", TEST_CHAIN_NAME);
        shouldUpgrade = vm.envOr("SHOULD_UPGRADE", false);
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[Size v1] upgrading...\n");

        console.log("[Size v1] chain:       ", chainName);
        console.log("[Size v1] deployer:    ", deployer);

        (ISize proxy,,,,,) = importDeployments();

        Size upgrade = new Size();
        console.log("[Size v1] new impl:    ", address(upgrade));

        if (shouldUpgrade) {
            Size(address(proxy)).upgradeToAndCall(address(upgrade), "");
            console.log("[Size v1] upgraded\n");
        } else {
            console.log("[Size v1] upgrade pending, call `upgradeToAndCall`\n");
        }

        console.log("[Size v1] done");
    }
}
