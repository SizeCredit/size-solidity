// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {NonTransferrableTokenVault} from "@src/market/token/NonTransferrableTokenVault.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract ReinitializeV1_8Test is BaseTest {
    bytes32 internal IS_USER_VAULT_WHITELIST_ENABLED_STORAGE_SLOT = bytes32(uint256(12));
    NonTransferrableTokenVault public borrowTokenVault;
    string name = "Token";
    string symbol = "TKN";

    function _rollbackToV1_7(address _borrowTokenVault) internal {
        // reset isUserVaultWhitelistEnabled to false (only useful for local tests)
        vm.store(_borrowTokenVault, IS_USER_VAULT_WHITELIST_ENABLED_STORAGE_SLOT, bytes32(uint256(0)));
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

    function test_ReinitializeV1_8_reinitialize_cannot_reinitialize_twice() public {
        assertEq(borrowTokenVault.isUserVaultWhitelistEnabled(), false);
        borrowTokenVault.reinitialize(name, symbol);
        assertEq(borrowTokenVault.isUserVaultWhitelistEnabled(), true);

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        borrowTokenVault.reinitialize(name, symbol);
    }
}
