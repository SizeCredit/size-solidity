// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";

contract RepayScript is Script {
    function run() external {
        console.log("REPAY...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        uint256 amount = 1e6; /// USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// RepayParams struct
        RepayParams memory params = RepayParams({loanId: 0, amount: amount});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.repay(params);
        vm.stopBroadcast();
    }
}
/* struct RepayParams {
    uint256 loanId;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
} */
