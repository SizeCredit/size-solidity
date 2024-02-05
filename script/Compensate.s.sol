// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract CompensateScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address usdcAddress = vm.envAddress("TOKEN_ADDRESS");

        uint256 amount = 1e6;

        /// USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// CompensateParams struct
        CompensateParams memory params = CompensateParams({loanToRepayId: 1, loanToCompensateId: 1, amount: amount});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.compensate(params);
        vm.stopBroadcast();
    }
}
/* struct CompensateParams {
    uint256 loanToRepayId;
    uint256 loanToCompensateId;
    uint256 amount; // in decimals (e.g. 1_000e6 for 1000 USDC)
} */
