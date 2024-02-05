// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract DepositScript is Script {
    function run() external {
        console.log("deposit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address usdcAddress = vm.envAddress("TOKEN_ADDRESS");

        uint256 amount = 1e6;

        /// USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// DepositParams struct
        DepositParams memory params = DepositParams({token: usdcAddress, amount: amount, to: sizeContractAddress});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.deposit(params);
        vm.stopBroadcast();
    }
}
