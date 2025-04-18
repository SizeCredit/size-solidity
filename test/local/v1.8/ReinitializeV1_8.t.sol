// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableTokenVault} from "@src/market/token/NonTransferrableTokenVault.sol";
import {BaseTest} from "@test/BaseTest.sol";

// TODO implement this
contract ReinitializeV1_8Test is BaseTest {
    bytes32 internal SIZE_FACTORY_SLOT = bytes32(uint256(28)); // calculated with the help of `cast storage`
    NonTransferrableTokenVault public borrowTokenVault;
    string name = "Token";
    string symbol = "TKN";

    function _rollbackToV1_7(address _borrowTokenVault) internal {
        // reset sizeFactory to 0 address (only useful for local tests)
        vm.store(_borrowTokenVault, SIZE_FACTORY_SLOT, bytes32(uint256(uint160(address(0)))));
    }

    function setUp() public override {
        super.setUp();
        borrowTokenVault = NonTransferrableTokenVault(address(size.data().borrowTokenVault));
        _rollbackToV1_7(address(borrowTokenVault));
    }

    function test_ReinitializeV1_8_reinitialize_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        borrowTokenVault.reinitialize(name, symbol);
    }

    function test_ReinitializeV1_8_reinitialize_not_null() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        borrowTokenVault.reinitialize(name, symbol);
    }

    function test_ReinitializeV1_8_reinitialize_cannot_reinitialize_twice() public {
        borrowTokenVault.reinitialize(name, symbol);
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        borrowTokenVault.reinitialize(name, symbol);
    }

    function test_ReinitializeV1_8_reinitialize_cannot_call_for_markets_deployed_after_v1_8() public {
        vm.store(address(borrowTokenVault), SIZE_FACTORY_SLOT, bytes32(uint256(uint160(address(sizeFactory)))));
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_SUPPORTED.selector));
        borrowTokenVault.reinitialize(name, symbol);
    }
}
