// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SizeFactoryMock is Ownable {
    constructor(address _owner) Ownable(_owner) {}

    mapping(address => bool) public isMarket;

    function setMarket(address _market, bool _isMarket) external onlyOwner {
        isMarket[_market] = _isMarket;
    }
}
