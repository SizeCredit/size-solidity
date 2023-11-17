// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPriceFeed {
    function getPrice() external view returns (uint256);
}
