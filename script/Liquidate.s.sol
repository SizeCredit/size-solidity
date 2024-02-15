// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract LiquidateScript is Script, Logger {
    function run() external {
        console.log("Liquidating...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        Size sizeContract = Size(sizeContractAddress);

        LiquidateParams memory params = LiquidateParams({debtPositionId: 0, minimumCollateralProfit: 0});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidate(params);
        vm.stopBroadcast();

        logPositions(address(sizeContract));
    }
}
