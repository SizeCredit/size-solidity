// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

contract SizeReinitializeTest is BaseTest {
    address admin;

    function setUp() public override {
        super.setUp();
        admin = address(this); // The owner/admin from BaseTest setup
    }

    function test_Size_reinitialize_success() public {
        // Only DEFAULT_ADMIN_ROLE can call reinitialize
        vm.prank(admin);
        size.reinitialize();
        
        // Should complete without reverting
        // Reinitialize is mainly for upgrading reentrancy guard
    }

    function test_Size_reinitialize_reverts_unauthorized() public {
        // Should revert when called by non-admin
        vm.prank(alice);
        vm.expectRevert();
        size.reinitialize();
        
        vm.prank(bob);
        vm.expectRevert();
        size.reinitialize();
        
        vm.prank(candy);
        vm.expectRevert();
        size.reinitialize();
    }

    function test_Size_reinitialize_multiple_calls() public {
        // First call should succeed
        vm.prank(admin);
        size.reinitialize();
        
        // Second call should fail (already initialized to version 1.08.00)
        vm.prank(admin);
        vm.expectRevert();
        size.reinitialize();
    }

    function test_Size_reinitialize_from_different_admin() public {
        // Grant admin role to another user
        vm.prank(admin);
        size.grantRole(size.DEFAULT_ADMIN_ROLE(), alice);
        
        // Alice should be able to call reinitialize
        vm.prank(alice);
        size.reinitialize();
    }
}