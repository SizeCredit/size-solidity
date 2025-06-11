// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract SizeFactoryMock {
    mapping(address => bool) public isMarket;

    constructor(address market1, address market2) {
        isMarket[address(market1)] = true;
        isMarket[address(market2)] = true;
    }
}
