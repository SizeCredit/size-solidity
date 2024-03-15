// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {SizeView} from "@src/SizeView.sol";

import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
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
        SizeView size = SizeView(sizeContractAddress);
        uint256 debtPositionId = 0;

        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        uint256 apr = size.getBorrowOfferAPR(borrower, debtPosition.dueDate);
        uint256 minimumCollateralProfit = size.debtTokenAmountToCollateralTokenAmount(debtPosition.faceValue);

        LiquidateWithReplacementParams memory params = LiquidateWithReplacementParams({
            debtPositionId: debtPositionId,
            minAPR: apr,
            deadline: block.timestamp,
            borrower: borrower,
            minimumCollateralProfit: minimumCollateralProfit
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidateWithReplacement(params);
        vm.stopBroadcast();
    }
}
