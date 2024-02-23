// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {SizeView} from "@src/SizeView.sol";
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

        uint256 dueDate = size.getDebtPosition(debtPositionId).dueDate;
        uint256 rate = size.getBorrowOfferRate(borrower, dueDate);
        uint256 minimumCollateralProfit = size.debtTokenAmountToCollateralTokenAmount(size.faceValue(debtPositionId));

        LiquidateWithReplacementParams memory params = LiquidateWithReplacementParams({
            debtPositionId: debtPositionId,
            minRate: rate,
            deadline: block.timestamp,
            borrower: borrower,
            minimumCollateralProfit: minimumCollateralProfit
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidateWithReplacement(params);
        vm.stopBroadcast();

        log(address(sizeContract));
    }
}
