// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

interface IPriceFeed {
    function getPrice() external view returns (uint256);
    function decimals() external view returns (uint8);
}
