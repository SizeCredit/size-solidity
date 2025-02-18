// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/market/Size.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GrantRoleScript is Script {
    function run() external {
        console.log("GrantRole...");

        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address account = vm.envAddress("ACCOUNT");
        bytes32 role = keccak256(abi.encodePacked(vm.envString("ROLE")));

        Size size = Size(payable(sizeContractAddress));

        vm.startBroadcast();
        size.grantRole(role, account);
        vm.stopBroadcast();
    }
}
