// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract BorrowerExitScript is Script {
    function run() external {
        console.log("BorrowerExit...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        address LenderTest = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;

        address to = vm.addr(deployerPrivateKey);

        Size sizeContract = Size(sizeContractAddress);

        /// BorrowerExit struct
        BorrowerExitParams memory params = BorrowerExitParams({
            loanId: 0,
            borrowerToExitTo: LenderTest
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.borrowerExit(params);
        vm.stopBroadcast();
    }
}
