// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {ClaimParams} from "@src/libraries/actions/Claim.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract ClaimScript is Script {
    function run() external {
        console.log("Claim...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        Size size = Size(payable(sizeContractAddress));

        ClaimParams memory params = ClaimParams({creditPositionId: 1});

        vm.startBroadcast(deployerPrivateKey);
        size.claim(params);
        vm.stopBroadcast();
    }
}
