// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {UpdateConfigParams} from "@src/libraries/general/actions/UpdateConfig.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract UpdateConfig is Script {
    function run() external {
        console.log("UpdateConfig...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        bytes32 key = vm.envBytes32("KEY");
        uint256 value = vm.envUint("VALUE");

        Size size = Size(payable(sizeContractAddress));

        vm.startBroadcast(deployerPrivateKey);
        size.updateConfig(UpdateConfigParams({key: key, value: value}));
        vm.stopBroadcast();
    }
}
