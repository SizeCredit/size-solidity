// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";

contract DepositScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);
        
        address lender = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8; 
        uint256 amount = 1e6; /// USDC has 6 decimals
        address to = sizeContractAddress;

        LendAsMarketOrderParams memory params = LendAsMarketOrderParams({
            borrower: to,
            dueDate: 2592e3,
            amount: amount,
            exactAmountIn: false
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.lendAsMarketOrder(params);
        vm.stopBroadcast();
    }
}

/* struct LendAsMarketOrderParams {
    address borrower;
    uint256 dueDate;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
    bool exactAmountIn;
} */
