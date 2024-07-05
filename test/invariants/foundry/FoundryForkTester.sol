// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FoundryForkHandler} from "./FoundryForkHandler.sol";

import {PropertiesSpecifications} from "@test/invariants/PropertiesSpecifications.sol";
import {Test} from "forge-std/Test.sol";

contract FoundryForkTester is Test, PropertiesSpecifications {
    FoundryForkHandler public handler;

    function setUp() public {
        handler = new FoundryForkHandler();
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
