// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

abstract contract Properties {
    modifier user() {
        _;
    }

    string internal constant DEPOSIT_01 = "DEPOSIT_01: Deposit must credit the sender in wad";
    string internal constant WITHDRAW_01 = "WITHDRAW_01: Withdraw must deduct from the sender in wad";
}
