// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import {PropertiesSpec} from "@test/invariants/PropertiesSpec.sol";
import {Test} from "forge-std/Test.sol";

contract Handler is TargetFunctions, FoundryAsserts {
    constructor() {
        vm.deal(address(USER1), 100e18);
        vm.deal(address(USER2), 100e18);
        vm.deal(address(USER3), 100e18);

        setup();
    }

    modifier getSender() override {
        sender = uint160(msg.sender) % 3 == 0
            ? address(USER1)
            : uint160(msg.sender) % 3 == 1 ? address(USER2) : address(USER3);
        _;
    }
}

contract FoundryTester is Test, PropertiesSpec {
    Handler public handler;

    function setUp() public {
        handler = new Handler();
        targetContract(address(handler));
    }

    function invariant() public {
        assertTrue(handler.invariant_LOAN_01(), LOAN_01);
        assertTrue(handler.invariant_UNDERWATER_01(), UNDERWATER_01);
        assertTrue(handler.invariant_TOKENS_01(), TOKENS_01);
    }
}
