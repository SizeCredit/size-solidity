// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";

contract InitializeTest is BaseTest {
    function test_Initialize_implementation_cannot_be_initialized() public {
        Size implementation = new Size();
        vm.expectRevert();
        implementation.initialize(g, f, v);

        assertEq(implementation.fixedConfig().crLiquidation, 0);
    }

    function test_Initialize_proxy_can_be_initialized() public {
        Size implementation = new Size();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(implementation), abi.encodeWithSelector(Size.initialize.selector, g, f, v));

        assertEq(Size(address(proxy)).fixedConfig().crLiquidation, 1.3e18);
    }
}
