// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";
import {CompensateParams} from "@src/libraries/actions/Compensate.sol";
import {Logger} from "@test/Logger.sol";
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
        Size size = Size(payable(sizeContractAddress));

        console.log(currentAddress);

        uint256 balance = size.getUserView(currentAddress).collateralTokenBalance;
        uint256 debt = size.getUserView(currentAddress).debtBalance;

        console.log("balance", balance);
        console.log("debt", debt);

        CompensateParams memory params =
            CompensateParams({creditPositionWithDebtToRepayId: 111, creditPositionToCompensateId: 123, amount: debt});

        vm.startBroadcast(deployerPrivateKey);
        size.compensate(params);
        vm.stopBroadcast();
    }
}
