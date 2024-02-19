// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {SizeView} from "@src/SizeView.sol";
import {CreditPosition, DebtPosition, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {console2 as console} from "forge-std/console2.sol";

abstract contract Logger {
    using LoanLibrary for DebtPosition;

    function logPositions(address size) internal view {
        DebtPosition[] memory debtPositions = SizeView(size).getDebtPositions();

        for (uint256 i = 0; i < debtPositions.length; i++) {
            console.log("Loan Index:", i);
            console.log("Lender Address:", debtPositions[i].lender);
            console.log("Borrower Address:", debtPositions[i].borrower);
            console.log("Issuance Value:", debtPositions[i].issuanceValue);
            console.log("Face Value:", debtPositions[i].faceValue());
            console.log("Rate:", debtPositions[i].rate);
            console.log("Start Date:", debtPositions[i].startDate);
            console.log("Due Date:", debtPositions[i].dueDate);

            CreditPosition[] memory creditPositions = SizeView(size).getCreditPositionsByDebtPositionId(i);

            for (uint256 j = 0; j < creditPositions.length; j++) {
                CreditPosition memory creditPosition = creditPositions[j];
                console.log("\tCredit Position Id:", i);
                console.log("\tLender Address:", creditPosition.lender);
                console.log("\tBorrower Address:", creditPosition.borrower);
                console.log("\tCredit:", creditPosition.credit);
            }
        }
    }
}