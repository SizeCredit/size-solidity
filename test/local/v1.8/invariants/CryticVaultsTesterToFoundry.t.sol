// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

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
}
