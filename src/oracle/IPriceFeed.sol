// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IPriceFeed {
    function getPrice() external view returns (uint256);
}
