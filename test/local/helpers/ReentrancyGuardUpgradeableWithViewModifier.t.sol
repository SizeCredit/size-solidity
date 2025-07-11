// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Test} from "forge-std/Test.sol";

import {ReentrancyGuardUpgradeableWithViewModifier} from "@src/helpers/ReentrancyGuardUpgradeableWithViewModifier.sol";
import {AssertsHelper} from "@test/helpers/AssertsHelper.sol";

// Test contract that extends ReentrancyGuardUpgradeableWithViewModifier
contract ReentrancyContract is ReentrancyGuardUpgradeableWithViewModifier {
    uint256 public value;
    bool public reentrancyDetected;

    function initialize() external initializer {
        __ReentrancyGuard_init();
    }

    function normalFunction() external {
        value += 1;
    }

    function protectedViewFunction() external view nonReentrantView returns (uint256) {
        return value;
    }

    function protectedFunction() external nonReentrant {
        value += 10;
        // Try to call the view function while already in a non-reentrant context
        this.attemptViewCall();
    }

    function attemptViewCall() external view {
        // This will trigger the nonReentrantView modifier
        this.protectedViewFunction();
    }

    function simulateReentrancy() external nonReentrant {
        value += 100;
        // This should trigger the reentrancy detection in the view modifier
        try this.protectedViewFunction() {
            // Should not reach here
        } catch {
            reentrancyDetected = true;
        }
    }
}

contract ReentrancyGuardUpgradeableWithViewModifierTest is Test, AssertsHelper {
    ReentrancyContract public reentrancyContract;

    function setUp() public {
        reentrancyContract = new ReentrancyContract();
        reentrancyContract.initialize();
    }

    function test_ReentrancyGuardUpgradeableWithViewModifier_normal_operation() public {
        // Normal function should work
        reentrancyContract.normalFunction();
        assertEq(reentrancyContract.value(), 1);

        // Protected view function should work when not in reentrant context
        uint256 result = reentrancyContract.protectedViewFunction();
        assertEq(result, 1);
    }

    function test_ReentrancyGuardUpgradeableWithViewModifier_detects_reentrancy() public {
        // This should trigger the reentrancy detection
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        reentrancyContract.protectedFunction();
    }

    function test_ReentrancyGuardUpgradeableWithViewModifier_view_revert_on_reentrancy() public {
        // Test that the nonReentrantView modifier correctly detects reentrancy
        reentrancyContract.simulateReentrancy();

        // Should have detected reentrancy
        assertTrue(reentrancyContract.reentrancyDetected());
        assertEq(reentrancyContract.value(), 100); // The function should have executed before the view call
    }

    function test_ReentrancyGuardUpgradeableWithViewModifier_view_works_independently() public {
        // View function should work fine when called independently
        uint256 result = reentrancyContract.protectedViewFunction();
        assertEq(result, 0); // Initial value

        reentrancyContract.normalFunction();

        result = reentrancyContract.protectedViewFunction();
        assertEq(result, 1); // Updated value
    }
}
