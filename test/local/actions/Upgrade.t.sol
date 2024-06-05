// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {SizeMock} from "@test/mocks/SizeMock.sol";

import {Size} from "@src/Size.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract UpgradeTest is Test, BaseTest {
    function test_Upgrade_proxy_can_be_upgraded_with_uups_castingeneralConfig() public {
        address owner = address(this);
        Size v1 = new Size();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        Size v2 = new SizeMock();

        UUPSUpgradeable(address(proxy)).upgradeToAndCall(address(v2), "");
        assertEq(SizeMock(payable(proxy)).version(), 2);
    }

    function test_Upgrade_proxy_can_be_upgraded_directly() public {
        address owner = address(this);
        Size v1 = new Size();
        ERC1967Proxy proxy = new ERC1967Proxy(address(v1), abi.encodeCall(Size.initialize, (owner, f, r, o, d)));
        Size v2 = new SizeMock();

        Size(payable(proxy)).upgradeToAndCall(address(v2), "");
        assertEq(SizeMock(payable(proxy)).version(), 2);
    }
}
