// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract BorrowerExitScript is Script {
    function run() external {
        console.log("BorrowerExit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        address to = vm.addr(deployerPrivateKey);

        Size sizeContract = Size(sizeContractAddress);

        /// BorrowerExit struct
        BorrowerExitParams memory params = BorrowerExitParams({loanId: 0, borrowerToExitTo: to});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowerExit(params);
        vm.stopBroadcast();
    }
}
/* struct BorrowerExitParams {
    uint256 loanId;
    address borrowerToExitTo;
} */
