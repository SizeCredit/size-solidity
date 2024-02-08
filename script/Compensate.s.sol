// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../src/Size.sol";
import "forge-std/Script.sol";
import "../src/SizeView.sol";

contract CompensateScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address sizeContractAddress = vm.envAddress("SIZE_CONTRACT_ADDRESS");

        address LenderTest = 0xD20baecCd9F77fAA9E2C2B185F33483D7911f9C8;
        address BorrowerTest = 0x979Af411D048b453E3334C95F392012B3BbD6215;
      
        address currentAddress = vm.addr(deployerPrivateKey);
        Size sizeContract = Size(sizeContractAddress);
        SizeView sizeViewContract = SizeView(sizeContractAddress);

        console.log(currentAddress);

        uint256 getcredit = sizeViewContract.getCredit(2);
        uint256 balance = sizeViewContract
            .getUserView(currentAddress)
            .collateralAmount;
        uint256 debt = sizeViewContract.getUserView(currentAddress).debtAmount;

        FixedLoan[] memory loans = sizeViewContract.getFixedLoans();

        for (uint i = 0; i < loans.length; i++) {
            console.log("Loan Index:", i);
            console.log("Lender Address:", loans[i].generic.lender);
            console.log("Borrower Address:", loans[i].generic.borrower);
            console.log("Credit:", loans[i].generic.credit);
            console.log("Issuance Value:", loans[i].fol.issuanceValue);
            console.log("Rate:", loans[i].fol.rate);
            console.log("Start Date:", loans[i].fol.startDate);
            console.log("Due Date:", loans[i].fol.dueDate);
        }

        console.log("balance", balance);
        console.log("debt", debt);

        /// CompensateParams struct
        CompensateParams memory params = CompensateParams({
            loanToRepayId: 2,
            loanToCompensateId: 2,
            amount: debt
        });

        vm.startBroadcast(deployerPrivateKey);
        sizeContract.compensate(params);
        vm.stopBroadcast();
    }
}
