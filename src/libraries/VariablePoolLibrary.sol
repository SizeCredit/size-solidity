// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./LoanLibrary.sol";

struct VariablePool {
    uint256 reserveUSDC;
    uint256 reserveETH;
    Loan[] activeLoans;
}
