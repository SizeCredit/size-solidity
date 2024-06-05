// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
import {Logger} from "@test/Logger.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract RepayScript is Script, Logger {
    function run() external {
        console.log("Repay...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size size = Size(payable(sizeContractAddress));

        RepayParams memory params = RepayParams({debtPositionId: 0});

        vm.startBroadcast(deployerPrivateKey);
        size.repay(params);
        vm.stopBroadcast();
    }
}
