// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";
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

contract FoundryTester is Test, PropertiesSpecifications {
    Handler public handler;

    function setUp() public {
        handler = new Handler();
        targetContract(address(handler));
    }

    function invariant() public {
        assertTrue(handler.property_LOAN());
        assertTrue(handler.property_UNDERWATER());
        assertTrue(handler.property_TOKENS());
        assertTrue(handler.property_SOLVENCY());
        assertTrue(handler.property_FEES());
    }
}
