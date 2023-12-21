// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {LoanStatus} from "@src/libraries/LoanLibrary.sol";

interface ISizeView {
    // When the loan is created, it is in ACTIVE status
    // When maturity is reached, it is in OVERDUE status
    // If the loan is not repaid and the CR is sufficient, it is moved to the Variable Pool,
    //   otherwise it is eligible for liquidation but if the CR < 100% then it will remain in
    //   the overdue state until the CR is > 100% or the lenders perform self liquidation
    // When the loan is repaid either by the borrower or by the liquidator, it is in REPAID status
    // When the loan is claimed by the lender or if it has been fully exited, it is in CLAIMED status
    function getLoanStatus(uint256 loanId) external returns (LoanStatus);
}
