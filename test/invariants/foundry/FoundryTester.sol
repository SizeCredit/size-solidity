// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FoundryHandler} from "./FoundryHandler.sol";

import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";
import {Test} from "forge-std/Test.sol";

contract FoundryTester is Test, PropertiesSpecifications {
    FoundryHandler public handler;

    function setUp() public {
        handler = new FoundryHandler();
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
