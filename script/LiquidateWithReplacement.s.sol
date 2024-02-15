// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract LiquidateWithReplacementScript is Script, Logger {
    function run() external {
        console.log("Liquidating...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("lender", lender);
        console.log("borrower", borrower);

        Size sizeContract = Size(sizeContractAddress);

        /// LiquidateLoanParams struct
        LiquidateWithReplacementParams memory params =
            LiquidateWithReplacementParams({debtPositionId: 0, borrower: borrower, minimumCollateralProfit: 0});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidateWithReplacement(params);
        vm.stopBroadcast();

        logPositions(address(sizeContract));
    }
}
