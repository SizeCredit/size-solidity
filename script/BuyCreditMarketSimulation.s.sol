// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/market/Size.sol";
import {Events} from "@src/market/libraries/Events.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {Logger} from "@test/Logger.sol";
import {Script} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BuyCreditMarketSimulationScript is Script, Logger {
    function run() external {
        Size size = Size(payable(vm.envAddress("SIZE_ADDRESS")));

        uint256 tenor = 30 days;
        address lender = address(vm.envAddress("LENDER"));
        address borrower = address(vm.envAddress("BORROWER"));
        uint256 amount = 100e6;
        uint256 apr = size.getUserDefinedBorrowOfferAPR(borrower, tenor);

        BuyCreditMarketParams memory params = BuyCreditMarketParams({
            borrower: borrower,
            creditPositionId: RESERVED_ID,
            tenor: tenor,
            amount: amount,
            deadline: block.timestamp,
            minAPR: apr,
            exactAmountIn: false,
            collectionId: RESERVED_ID,
            rateProvider: address(0)
        });

        vm.recordLogs();

        vm.prank(lender);
        size.buyCreditMarket(params);

        Vm.Log[] memory entries = vm.getRecordedLogs();
        Vm.Log memory swapData;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == Events.SwapData.selector) {
                swapData = entries[i];
                break;
            }
        }

        (uint256 credit, uint256 cashIn, uint256 cashOut, uint256 swapFee, uint256 fragmentationFee,) =
            abi.decode(swapData.data, (uint256, uint256, uint256, uint256, uint256, uint256));

        console.log("credit: %s", credit);
        console.log("cashIn: %s", cashIn);
        console.log("cashOut: %s", cashOut);
        console.log("swapFee: %s", swapFee);
        console.log("fragmentationFee: %s", fragmentationFee);
    }
}
