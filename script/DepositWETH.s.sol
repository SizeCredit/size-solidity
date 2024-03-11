// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract DepositWETHScript is Script {
    function run() external {
        console.log("Deposit WETH...");
        //TODO approve on script
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");

        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        uint256 amount = 0.01e18;

        /// WETH has 18 decimals

        console.log("lender", lender);
        console.log("borrower", borrower);

        Size sizeContract = Size(sizeContractAddress);

        DepositParams memory params = DepositParams({token: wethAddress, amount: amount, to: borrower, variable: false});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.deposit(params);
        vm.stopBroadcast();
    }
}
