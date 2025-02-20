// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract ReinitializeV1_7Test is BaseTest {
    bytes32 internal SIZE_FACTORY_SLOT = bytes32(uint256(28)); // calculated with the help of `cast storage`

    function setUp() public override {
        super.setUp();
        // reset sizeFactory to 0 address (only useful for local tests)
        vm.store(address(size), SIZE_FACTORY_SLOT, bytes32(uint256(uint160(address(0)))));
    }

    function test_ReinitializeV1_7_reinitialize_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
        size.reinitialize(sizeFactory);
    }

    function test_ReinitializeV1_7_reinitialize_not_null() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        size.reinitialize(ISizeFactory(address(0)));
    }

    function test_ReinitializeV1_7_reinitialize_must_be_market() public {
        sizeFactory.removeMarket(size);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MARKET.selector, address(size)));
        size.reinitialize(sizeFactory);
    }

    function test_ReinitializeV1_7_reinitialize_cannot_reinitialize_twice() public {
        size.reinitialize(sizeFactory);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        size.reinitialize(sizeFactory);
    }

    function test_ReinitializeV1_7_reinitialize_cannot_call_for_markets_deployed_after_v1_7() public {
        vm.store(address(size), SIZE_FACTORY_SLOT, bytes32(uint256(uint160(address(sizeFactory)))));
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        size.reinitialize(sizeFactory);
    }
}
