// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract LiquidateFixedLoanWithRScript is Script {
    function run() external {
        console.log("Liquidating...");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        uint256 amount = 1e6;

        /// USDC has 6 decimals
        address borrower = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8; //vm.envAddress("BORROWER");
        Size sizeContract = Size(sizeContractAddress);

        /// LiquidateFixedLoanParams struct
        LiquidateFixedLoanWithReplacementParams memory params =
            LiquidateFixedLoanWithReplacementParams({loanId: 0, borrower: borrower, minimumCollateralRatio: amount});

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.liquidateFixedLoanWithReplacement(params);
        vm.stopBroadcast();
    }
}

