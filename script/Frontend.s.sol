// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/market/Size.sol";
import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract FrontendScript is Script {
    function run() external {
        console.log("Frontend...");

        Size size = Size(payable(vm.envAddress("SIZE_ADDRESS")));
        address user = vm.envAddress("USER_ADDRESS");
        bytes memory data = vm.envBytes("DATA");

        vm.prank(user);
        (bool success,) = address(size).call(data);
        console.log("success", success);
    }
}
