// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract ClaimScript is Script {
    function run() external {
        console.log("Claim...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address usdcAddress = vm.envAddress("TOKEN_ADDRESS");

        uint256 amount = 1e6;

        /// USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// Claim struct
        ClaimParams memory params = ClaimParams({loanId: 10});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.claim(params);
        vm.stopBroadcast();
    }
}
/* struct ClaimParams {
    uint256 loanId;
} */
