// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {VaultsTargetFunctions} from "@test/local/v1.8/invariants/VaultsTargetFunctions.sol";

import {Asserts} from "@chimera/Asserts.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {SetupLocal} from "@test/invariants/SetupLocal.sol";
import {console} from "forge-std/console.sol";

import {Logger} from "@test/Logger.sol";

import {BaseTest} from "@test/BaseTest.sol";

contract CryticVaultsTesterToFoundry is BaseTest, VaultsTargetFunctions, FoundryAsserts, Logger {
    function setUp() public override {
        vm.deal(address(USER1), 100e18);
        vm.deal(address(USER2), 100e18);
        vm.deal(address(USER3), 100e18);

        vm.warp(1524785992);
        vm.roll(4370000);

        setup();

        sender = USER1;

        _labels();
    }

    modifier getSender() override {
        _;
    }

    function test_CryticVaultsTesterToFoundry_1() public {
        maliciousVault_setSize(false);
        token_approve(1);
        borrowTokenVault_setVault(address(0xdeadbeef), address(0x16), false);
        size_deposit(1, address(0x30000));
        maliciousVault_setOperation(0x0000003e);
        maliciousVault_setReenterCount(1);
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        borrowTokenVault_setVault(address(0xdeadbeef), address(0x0), false);
    }

    function test_CryticVaultsTesterToFoundry_2() public {
        sender = 0x0000000000000000000000000000000000020000;
        borrowTokenVault_setVault(address(0xdeadbeef), address(0x16), false);
        sender = 0x0000000000000000000000000000000000030000;
        maliciousVault_setSize(true);
        sender = 0x0000000000000000000000000000000000030000;
        token_approve(1524785991);
        sender = 0x0000000000000000000000000000000000030000;
        size_deposit(4370000, address(0x30000));
        sender = 0x0000000000000000000000000000000000010000;
        maliciousVault_setOperation(0x713fc232);
        sender = 0x0000000000000000000000000000000000010000;
        maliciousVault_setReenterCount(81);
        sender = 0x0000000000000000000000000000000000030000;
        vm.expectRevert(ReentrancyGuardUpgradeable.ReentrancyGuardReentrantCall.selector);
        size_withdraw(68625291814337064871416729962860020715493080276270229296212733239041971906714, address(0x20000));
    }
}
