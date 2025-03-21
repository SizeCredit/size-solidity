// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {SizeView} from "@src/market/SizeView.sol";

import {Logger} from "@test/Logger.sol";

import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GetUserViewScript is Script, Logger {
    using OfferLibrary for LimitOrder;

    function run() external {
        console.log("GetUserView...");

        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address lender = vm.envAddress("LENDER");

        SizeView size = SizeView(sizeContractAddress);

        vm.startBroadcast();
        _log(size.getUserView(lender));
        vm.stopBroadcast();
    }
}
