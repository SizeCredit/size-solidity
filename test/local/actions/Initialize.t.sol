// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Size} from "@src/Size.sol";

contract InitializeTest is BaseTest {
    function test_Initialize_implementation_cannot_be_initialized() public {
        address owner = address(this);
        Size implementation = new Size();
        vm.expectRevert();
        implementation.initialize(owner, f, r, o, d);

        assertEq(implementation.riskConfig().crLiquidation, 0);
        assertEq(Size(payable(proxy)).oracle().priceFeed, address(priceFeed));
    }

    function test_Initialize_proxy_can_be_initialized() public {
        address owner = address(this);
        Size implementation = new Size();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation), abi.encodeWithSelector(Size.initialize.selector, owner, f, r, o, d)
        );

        assertEq(Size(payable(proxy)).riskConfig().crLiquidation, 1.3e18);
    }

    function test_Initialize_wrong_initialization_reverts() public {
        Size implementation = new Size();

        vm.expectRevert();
        new ERC1967Proxy(address(implementation), abi.encodeWithSelector(Size.initialize.selector, f, r, o, d));
    }
}
