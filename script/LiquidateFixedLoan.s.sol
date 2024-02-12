// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract LiquidateLoanScript is Script {
    function run() external {
        console.log("Liquidating...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        uint256 amount = 1e6; // USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// LiquidateLoanParams struct
        LiquidateLoanParams memory params = LiquidateLoanParams({loanId: 0, minimumCollateralProfit: amount});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidateLoan(params);
        vm.stopBroadcast();
    }
}
