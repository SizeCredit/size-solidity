// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";

import {RESERVED_ID} from "@src/libraries/fixed/LoanLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/fixed/actions/BuyCreditMarket.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BuyCreditMarketScript is Script, Logger {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size size = Size(payable(sizeContractAddress));

        uint256 dueDate = block.timestamp + 30 days; // 30 days from now

        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("lender", lender);
        console.log("borrower", borrower);

        uint256 amount = 6e6;

        uint256 apr = size.getBorrowOfferAPR(borrower, dueDate);

        BuyCreditMarketParams memory params = BuyCreditMarketParams({
            borrower: borrower,
            creditPositionId: RESERVED_ID,
            dueDate: dueDate,
            amount: amount,
            deadline: block.timestamp,
            minAPR: apr,
            exactAmountIn: false
        });
        console.log("lender USDC", size.getUserView(lender).borrowATokenBalance);
        vm.startBroadcast(deployerPrivateKey);
        size.buyCreditMarket(params);
        vm.stopBroadcast();
    }
}
