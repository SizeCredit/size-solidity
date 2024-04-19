// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {Logger} from "@test/Logger.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BorrowAsMarketOrderScript is Script, Logger {
    using OfferLibrary for LoanOffer;

    function run() external {
        console.log("BorrowAsMarketOrder...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address lender = vm.envAddress("LENDER");

        console.log("lender", lender);

        uint256 dueDate = block.timestamp + 4 days;

        Size size = Size(payable(sizeContractAddress));
        uint256 apr = size.getLoanOfferAPR(lender, dueDate);

        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: lender,
            amount: 5e6,
            dueDate: dueDate,
            deadline: block.timestamp,
            maxAPR: apr,
            exactAmountIn: false,
            receivableCreditPositionIds: new uint256[](0)
        });
        vm.startBroadcast(deployerPrivateKey);
        size.borrowAsMarketOrder(params);
        vm.stopBroadcast();
    }
}
