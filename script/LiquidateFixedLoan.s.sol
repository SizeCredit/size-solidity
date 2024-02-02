// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Size.sol";

contract LiquidateFixedLoanScript is Script {
    function run() external {
        console.log("Liquidating...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        uint256 amount = 1e6; /// USDC has 6 decimals

        Size sizeContract = Size(sizeContractAddress);

        /// LiquidateFixedLoanParams struct
        LiquidateFixedLoanParams memory params = LiquidateFixedLoanParams({
            loanId: 0,
            minimumCollateralRatio: amount
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidateFixedLoan(params);
        vm.stopBroadcast();
    }
}
/* struct LiquidateFixedLoanParams {
    uint256 loanId;
    uint256 minimumCollateralRatio;
} */
