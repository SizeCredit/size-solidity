// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";

import {FoundryTester} from "./FoundryTester.sol";

// forge test --mc FoundryInvariants
contract FoundryInvariants is Test {
    FoundryTester internal handler;

    function setUp() public {
        handler = new FoundryTester();

        targetContract(address(handler));
    }

    function invariant() public {
        assertTrue(true);
    }
}
