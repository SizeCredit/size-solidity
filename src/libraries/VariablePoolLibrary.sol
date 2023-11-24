// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "@src/libraries/LoanLibrary.sol";

struct VariablePool {
    uint256 reserveUSDC;
    uint256 reserveETH;
    Loan[] activeLoans;
}
