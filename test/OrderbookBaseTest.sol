// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "./mocks/OrderbookMock.sol";
import "./mocks/PriceFeedMock.sol";

contract OrderbookBaseTest is Test {
    OrderbookMock public orderbook;
    PriceFeedMock public priceFeed;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new OrderbookMock()),
            abi.encodeWithSelector(
                Orderbook.initialize.selector,
                address(this),
                priceFeed,
                12,
                1.5e18,
                1.3e18
            )
        );
        orderbook = OrderbookMock(address(proxy));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
    }
}
