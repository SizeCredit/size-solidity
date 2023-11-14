// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "../src/Size.sol";
import {SizeMock} from "./mocks/SizeMock.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

contract BaseTest is Test {
    SizeMock public size;
    PriceFeedMock public priceFeed;

    address public alice = address(0x10000);
    address public bob = address(0x20000);
    address public candy = address(0x30000);
    address public james = address(0x40000);
    address public liquidator = address(0x50000);

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(new SizeMock()),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                priceFeed,
                12,
                1.5e18,
                1.3e18
            )
        );
        size = SizeMock(address(proxy));

        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(candy, "candy");
        vm.label(james, "james");
        vm.label(liquidator, "liquidator");
    }
}
