// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";

contract InitializeTest is BaseTest {
    function test_Initialize_implementation_cannot_be_initialized() public {
        Size implementation = new Size();
        vm.expectRevert();
        implementation.initialize(params, extraParams);

        assertEq(implementation.f().crLiquidation, 0);
    }

    function test_Initialize_proxy_can_be_initialized() public {
        Size implementation = new Size();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(Size.initialize.selector, params, extraParams)
        );

        assertEq(Size(address(proxy)).f().crLiquidation, 1.3e18);
    }
}
