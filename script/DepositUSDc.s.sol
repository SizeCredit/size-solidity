// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";

contract DepositScript is Script {
    function run() external {
        console.log("deposit...");

        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address usdcAddress = vm.envAddress("TOKEN_ADDRESS");

        uint256 amount = 1000000; /// USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// DepositParams struct
        DepositParams memory params = DepositParams({
            token: usdcAddress,
            amount: amount,
            to: sizeContractAddress
        });

        vm.startBroadcast();
        sizeContract.deposit(params);
        vm.stopBroadcast();
    }
}
