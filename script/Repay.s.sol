// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract RepayScript is Script {
    function run() external {
        console.log("REPAY...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        Size sizeContract = Size(sizeContractAddress);

        /// RepayParams struct
        RepayParams memory params = RepayParams({loanId: 0});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.repay(params);
        vm.stopBroadcast();
    }
}
