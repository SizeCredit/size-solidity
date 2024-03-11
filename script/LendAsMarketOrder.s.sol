// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract LendAsMarketOrderScript is Script, Logger {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        uint256 dueDate = block.timestamp + 30 days; // 30 days from now

        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("lender", lender);
        console.log("borrower", borrower);

        uint256 amount = 6e6;

        uint256 apr = sizeContract.getBorrowOfferAPR(borrower, dueDate);

        LendAsMarketOrderParams memory params = LendAsMarketOrderParams({
            borrower: borrower,
            dueDate: dueDate,
            amount: amount,
            deadline: block.timestamp,
            minAPR: apr,
            exactAmountIn: false
        });
        console.log("lender USDC", sizeContract.getUserView(lender).borrowATokenBalanceFixed);
        vm.startBroadcast(deployerPrivateKey);
        sizeContract.lendAsMarketOrder(params);
        vm.stopBroadcast();
    }
}
