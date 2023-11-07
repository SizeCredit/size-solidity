// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPriceFeed {
    function getPrice() external returns (uint256);
}
