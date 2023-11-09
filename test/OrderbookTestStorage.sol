// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./mocks/OrderbookMock.sol";
import "./mocks/PriceFeedMock.sol";

contract OrderbookTestStorage {
    OrderbookMock public orderbook;
    PriceFeedMock public priceFeed;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);
}
