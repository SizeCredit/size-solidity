// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";

contract CompensateScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        address LenderTest = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;
        address BorrowerTest = 0x979Af411D048b453E3334C95F392012B3BbD6215;
        uint256 amount = 1e6;

        address currentAddress = vm.addr(deployerPrivateKey);
        Size sizeContract = Size(sizeContractAddress);
        uint256 repaidFixedLoanDebtAfter = sizeContract.getFixedLoan(2).debt;
        /// CompensateParams struct
        CompensateParams memory params = CompensateParams({
            loanToRepayId: 2,
            loanToCompensateId: 2,
            amount: repaidFixedLoanDebtAfter
        });

        console.log(currentAddress);

        address compensatedFixedLoanCreditAfter = sizeContract
            .getFixedLoan(2)
            .lender;
        console.log(sizeContract.getFixedLoan(2).borrower);
        //console.log(compensatedFixedLoanCreditAfter);
        console.log(repaidFixedLoanDebtAfter);
        vm.startBroadcast(deployerPrivateKey);
        sizeContract.compensate(params);
        vm.stopBroadcast();
    }
}
