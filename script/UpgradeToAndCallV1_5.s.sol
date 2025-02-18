// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {console2 as console} from "forge-std/Script.sol";

import {Size} from "@src/market/Size.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {BaseScript} from "@script/BaseScript.sol";
import {Deploy} from "@script/Deploy.sol";
import {Networks} from "@script/Networks.sol";

contract UpgradeToAndCallV1_5Script is BaseScript, Networks, Deploy {
    string networkConfiguration;

    EnumerableMap.AddressToUintMap addresses;

    function setUp() public {}

    modifier parseEnv() {
        networkConfiguration = vm.envOr("NETWORK_CONFIGURATION", TEST_NETWORK_CONFIGURATION);
        _;
    }

    function run() public parseEnv broadcast {
        console.log("[Size v1] upgrading...\n");

        console.log("[Size v1] networkConfiguration", networkConfiguration);

        (ISize proxy,,) = importDeployments(networkConfiguration);

        (, bytes memory data) = importV1_5ReinitializeData(networkConfiguration, addresses);

        Size upgrade = new Size();
        console.log("[Size v1] new implementation", address(upgrade));

        Size(address(proxy)).upgradeToAndCall(address(upgrade), data);
        console.log("[Size v1] upgraded\n");

        console.log("[Size v1] done");
    }
}
