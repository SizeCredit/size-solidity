// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";

interface ISizeView {
    // When the loan is created, it is in active status
    // When maturity is reached
    // If the loan is not repaid and the CR is sufficient, it is moved to the Variable Pool
    // Otherwise it is eligible for liquidation but if the CR < 100% then it will remain in the overdue state until the CR is > 100% or the lenders perform self liquidation
    // When the loan is repaid either by the borrower or by the liquidator, it is in repaid status
    // When the loan is claimed by the lender, it is in claimed status
    function getLoanStatus(uint256 loanId) external returns (LoanStatus);
}
