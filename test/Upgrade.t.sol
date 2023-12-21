// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SizeV2} from "./mocks/SizeV2.sol";

import {BaseTest, Vars} from "./BaseTest.sol";
import {Size} from "@src/Size.sol";

contract UpgradeTest is Test, BaseTest {
    function test_SizeUpgrade_proxy_can_be_upgraded_with_uups_casting() public {
        Size v1 = new Size();
        proxy = new ERC1967Proxy(address(v1), abi.encodeCall(Size.initialize, (params, extraParams)));
        Size v2 = new SizeV2();

        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(v2), "");
        assertEq(SizeV2(address(proxy)).version(), 2);
    }

    function test_SizeUpgrade_proxy_can_be_upgraded_directly() public {
        Size v1 = new Size();
        proxy = new ERC1967Proxy(address(v1), abi.encodeCall(Size.initialize, (params, extraParams)));
        Size v2 = new SizeV2();

        Size(address(proxy)).upgradeToAndCall(address(v2), "");
        assertEq(SizeV2(address(proxy)).version(), 2);
    }
}
