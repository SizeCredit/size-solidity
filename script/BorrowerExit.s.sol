// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Size} from "@src/Size.sol";
import {SizeView} from "@src/SizeView.sol";
import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BorrowerExitScript is Script {
    function run() external {
        console.log("BorrowerExit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address borrower = vm.envAddress("BORROWER");

        uint256 debtPositionId = 1;

        console.log("borrower", borrower);

        Size sizeContract = Size(sizeContractAddress);
        uint256 dueDate = SizeView(address(sizeContract)).getDebtPosition(debtPositionId).dueDate;
        uint256 rate = SizeView(address(sizeContract)).getBorrowOfferRatePerMaturity(borrower, dueDate);
        BorrowerExitParams memory params = BorrowerExitParams({
            debtPositionId: debtPositionId,
            borrowerToExitTo: borrower,
            minRatePerMaturity: rate,
            deadline: block.timestamp
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowerExit(params);
        vm.stopBroadcast();
    }
}
