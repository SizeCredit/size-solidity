// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {Logger} from "@test/Logger.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BuyCreditMarketScript is Script, Logger {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size size = Size(payable(sizeContractAddress));

        uint256 tenor = 30 days;

        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("lender", lender);
        console.log("borrower", borrower);

        uint256 amount = 6e6;

        uint256 apr = size.getBorrowOfferAPR(borrower, tenor);

        BuyCreditMarketParams memory params = BuyCreditMarketParams({
            borrower: borrower,
            creditPositionId: RESERVED_ID,
            tenor: tenor,
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
