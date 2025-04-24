// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableTokenVault} from "@src/market/token/NonTransferrableTokenVault.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract ReinitializeV1_8Test is BaseTest {
    NonTransferrableTokenVault public borrowTokenVault;
    string name = "Token";
    string symbol = "TKN";

    function _rollbackToV1_7() internal {
        // reset isUserVaultWhitelisted[DEFAULT_VAIULT] to false (only useful for local tests)
        address k = address(borrowTokenVault.DEFAULT_VAULT());
        uint256 p = 11;
        bytes32 slot = keccak256(abi.encode(k, p));
        vm.store(address(borrowTokenVault), slot, bytes32(uint256(0)));
    }

    function setUp() public override {
        super.setUp();
        borrowTokenVault = NonTransferrableTokenVault(address(size.data().borrowTokenVault));
        _rollbackToV1_7();
    }

    function test_ReinitializeV1_8_reinitialize_onlyOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        borrowTokenVault.reinitialize(name, symbol);
    }

    function test_ReinitializeV1_8_reinitialize_cannot_reinitialize_twice() public {
        assertEq(borrowTokenVault.isUserVaultWhitelisted(borrowTokenVault.DEFAULT_VAULT()), false);
        borrowTokenVault.reinitialize(name, symbol);
        assertEq(borrowTokenVault.isUserVaultWhitelisted(borrowTokenVault.DEFAULT_VAULT()), true);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        borrowTokenVault.reinitialize(name, symbol);
    }
}
