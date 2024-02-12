// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";

import "./TimestampHelper.sol";
import "forge-std/Script.sol";

contract LendAsMarketOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        TimestampHelper helper = new TimestampHelper();
        uint256 currentTimestamp = helper.getCurrentTimestamp();
        uint256 dueDate = currentTimestamp + 60 * 60 * 24 * 30; // 30 days from now

        address LenderTest = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;
        address BorrowerTest = 0x979Af411D048b453E3334C95F392012B3BbD6215;

        uint256 amount = 6e6;

        /// USDC has 6 decimals

        LendAsMarketOrderParams memory params =
            LendAsMarketOrderParams({borrower: BorrowerTest, dueDate: dueDate, amount: amount, exactAmountIn: false});
        console.log("lender USDC", sizeContract.getUserView(LenderTest).borrowAmount);
        vm.startBroadcast(deployerPrivateKey);
        sizeContract.lendAsMarketOrder(params);
        vm.stopBroadcast();
    }
}
