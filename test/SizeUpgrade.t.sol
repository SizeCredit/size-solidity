// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {Size} from "../src/Size.sol";
import {SizeMock} from "./mocks/SizeMock.sol";
import {PriceFeedMock} from "./mocks/PriceFeedMock.sol";

contract SizeUpgradeTest is Test {
    Size public v1;
    SizeMock public v2;
    ERC1967Proxy public proxy;
    PriceFeedMock public priceFeed;

    function setUp() public {
        priceFeed = new PriceFeedMock(address(this));
    }

    function test_SizeUpgrade_proxy_can_be_upgraded() public {
        v1 = new Size();
        proxy = new ERC1967Proxy(
            address(v1),
            abi.encodeWithSelector(
                Size.initialize.selector,
                address(this),
                priceFeed,
                12,
                1.5e18,
                1.3e18
            )
        );
        v2 = new SizeMock();
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(v2), "");

        SizeMock(address(proxy)).setExpectedFV(address(0), 1, 2);
    }
}
