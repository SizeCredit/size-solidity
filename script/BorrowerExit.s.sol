// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Size} from "@src/Size.sol";
import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BorrowerExitScript is Script {
    function run() external {
        console.log("BorrowerExit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address borrower = vm.envAddress("BORROWER");

        console.log("borrower", borrower);

        Size sizeContract = Size(sizeContractAddress);
        BorrowerExitParams memory params = BorrowerExitParams({debtPositionId: 1, borrowerToExitTo: borrower});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowerExit(params);
        vm.stopBroadcast();
    }
}
