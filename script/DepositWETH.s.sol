// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@src/Size.sol";
import "forge-std/Script.sol";

contract DepositWETHScript is Script {
    function run() external {
        console.log("Deposit WETH...");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address wethAddress = vm.envAddress("WETH_ADDRESS");

        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        uint256 amount = 0.01e18;

        console.log("lender", lender);
        console.log("borrower", borrower);

        Size size = Size(payable(sizeContractAddress));

        DepositParams memory params = DepositParams({token: wethAddress, amount: amount, to: borrower});

        vm.startBroadcast(deployerPrivateKey);
        size.deposit(params);
        vm.stopBroadcast();
    }
}
