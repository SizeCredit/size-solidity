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

        address LenderTest = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;
        address BorrowerTest = 0x979Af411D048b453E3334C95F392012B3BbD6215;

        console.log("LenderTest", LenderTest);
        console.log("BorrowerTest", BorrowerTest);

        uint256 amount = 100e6; // USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// DepositParams struct
        DepositParams memory params = DepositParams({token: usdcAddress, amount: amount, to: BorrowerTest});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.deposit(params);
        vm.stopBroadcast();
    }
}
