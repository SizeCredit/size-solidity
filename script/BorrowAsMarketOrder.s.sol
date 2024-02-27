// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {SizeView} from "@src/SizeView.sol";
import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract BorrowAsMarketOrder is Script, Logger {
    function run() external {
        console.log("BorrowAsMarketOrder...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address lender = vm.envAddress("LENDER");

        console.log("lender", lender);

        uint256 dueDate = block.timestamp + 4 days;

        Size sizeContract = Size(sizeContractAddress);
        uint256 rate = SizeView(address(sizeContract)).getLoanOfferRatePerMaturity(lender, dueDate);

        BorrowAsMarketOrderParams memory params = BorrowAsMarketOrderParams({
            lender: lender,
            amount: 5e6,
            dueDate: dueDate,
            deadline: block.timestamp,
            maxAPR: rate,
            exactAmountIn: false,
            receivableCreditPositionIds: new uint256[](0)
        });
        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowAsMarketOrder(params);
        vm.stopBroadcast();

        log(address(sizeContract));
    }
}
