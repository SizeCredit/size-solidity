// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SizeView} from "@src/SizeView.sol";

import {Logger} from "@script/Logger.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GetUserViewScript is Script, Logger {
    function run() external {
        console.log("GetUserView...");

        SizeView size = SizeView(0x7FCfA10E45BecD82dbf1a50Ac281430A1272a5D6);

        vm.startBroadcast();
        log(size.getUserView(0xf44b17b31d0D364D43A77454424d5BB8Ac97AFD1));
        vm.stopBroadcast();
    }
}
