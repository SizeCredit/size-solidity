// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";

import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract DepositUSDCScript is Script {
    function run() external {
        console.log("Deposit USDC...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address usdcAddress = vm.envAddress("TOKEN_ADDRESS");
        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("lender", lender);
        console.log("borrower", borrower);

        uint256 amount = 100e6; // USDC has 6 decimals

        Size size = Size(payable(sizeContractAddress));

        /// DepositParams struct
        DepositParams memory params = DepositParams({token: usdcAddress, amount: amount, to: lender});

        vm.startBroadcast(deployerPrivateKey);
        size.deposit(params);
        vm.stopBroadcast();
    }
}
