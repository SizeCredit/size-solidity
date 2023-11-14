// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./LoanLibrary.sol";

struct AMM {
    uint256 reserveUSDC;
    uint256 reserveETH;
    uint256 fixedPrice;
}

library AMMLibrary {}
