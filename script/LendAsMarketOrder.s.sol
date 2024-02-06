// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";
import "./TimestampHelper.sol";

contract LendAsMarketOrderScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        TimestampHelper helper = new TimestampHelper();
        uint256 currentTimestamp = helper.getCurrentTimestamp();
        uint256 dueDate = currentTimestamp + 60 * 60 * 24 * 30; // 300 days from now

        address wallet1 = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;
        address wallet2 = 0x979Af411D048b453E3334C95F392012B3BbD6215;
        uint256 amount = 6e6; /// USDC has 6 decimals

        LendAsMarketOrderParams memory params = LendAsMarketOrderParams({
            borrower: wallet1,
            dueDate: dueDate,
            amount: amount,
            exactAmountIn: false
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.lendAsMarketOrder(params);
        vm.stopBroadcast();
    }
}
