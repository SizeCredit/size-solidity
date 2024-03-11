// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Logger} from "@script/Logger.sol";
import {Size} from "@src/Size.sol";
import {SizeView} from "@src/SizeView.sol";
import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract CompensateScript is Script, Logger {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");
        address lender = vm.envAddress("LENDER");
        address borrower = vm.envAddress("BORROWER");

        console.log("lender", lender);
        console.log("borrower", borrower);

        address currentAddress = vm.addr(deployerPrivateKey);
        Size size = Size(sizeContractAddress);
        SizeView sizeView = SizeView(sizeContractAddress);

        console.log(currentAddress);

        uint256 balance = sizeView.getUserView(currentAddress).collateralTokenBalanceFixed;
        uint256 debt = sizeView.getUserView(currentAddress).debtBalance;

        console.log("balance", balance);
        console.log("debt", debt);

        CompensateParams memory params =
            CompensateParams({creditPositionWithDebtToRepayId: 111, creditPositionToCompensateId: 123, amount: debt});

        vm.startBroadcast(deployerPrivateKey);
        size.compensate(params);
        vm.stopBroadcast();
    }
}
