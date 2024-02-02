// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";

contract DepositScript is Script {
    function run() external {
        console.log("deposit...");
        //TODO approve on script
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");

        uint256 amount = 1e15; /// WETH has 18 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// DepositParams struct
        DepositParams memory params = DepositParams({
            token: wethAddress,
            amount: amount,
            to: sizeContractAddress
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.deposit(params);
        vm.stopBroadcast();
    }
}
