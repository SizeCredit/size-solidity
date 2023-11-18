// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "../src/Size.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

contract SizeInitializeTest is Test {
    Size public implementation;
    ERC1967Proxy public proxy;
    PriceFeedMock public priceFeed;

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
    }

    function test_SizeInitialize_implementation_cannot_be_initialized() public {
        implementation = new Size();
        vm.expectRevert();
        implementation.initialize(address(this), priceFeed, 12, 1.5e18, 1.3e18, 0.3e18, 0.1e18);

        assertEq(implementation.CRLiquidation(), 0);
    }

    function test_SizeInitialize_proxy_can_be_initialized() public {
        implementation = new Size();
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                priceFeed,
                12,
                1.5e18,
                1.3e18,
                0.3e18,
                0.1e18
            )
        );

        assertEq(Size(address(proxy)).CRLiquidation(), 1.3e18);
    }
}
