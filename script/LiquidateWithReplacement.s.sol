// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {Logger} from "@test/Logger.sol";

import {DebtPosition} from "@src/libraries/LoanLibrary.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/actions/LiquidateWithReplacement.sol";
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

        Size size = Size(payable(sizeContractAddress));
        uint256 debtPositionId = 0;

        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        uint256 apr = size.getBorrowOfferAPR(borrower, debtPosition.dueDate);
        uint256 minimumCollateralProfit = size.debtTokenAmountToCollateralTokenAmount(debtPosition.futureValue);

        LiquidateWithReplacementParams memory params = LiquidateWithReplacementParams({
            debtPositionId: debtPositionId,
            minAPR: apr,
            deadline: block.timestamp,
            borrower: borrower,
            minimumCollateralProfit: minimumCollateralProfit
        });

        vm.startBroadcast(deployerPrivateKey);
        size.liquidateWithReplacement(params);
        vm.stopBroadcast();
    }
}
