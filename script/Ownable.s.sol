// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract OwnableScript is Script {
    function run() external {
        console.log("Ownable...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        address newOwner = vm.envAddress("NEW_OWNER");

        Ownable ownable = Ownable(contractAddress);

        vm.startBroadcast(deployerPrivateKey);
        ownable.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
