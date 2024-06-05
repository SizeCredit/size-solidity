// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract GrantRoleScript is Script {
    function run() external {
        console.log("GrantRole...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address account = vm.envAddress("ACCOUNT");
        bytes32 role = vm.envBytes32("ROLE");

        Size size = Size(payable(sizeContractAddress));

        vm.startBroadcast(deployerPrivateKey);
        size.grantRole(role, account);
        vm.stopBroadcast();
    }
}
