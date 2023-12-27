// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

contract FoundryTester is TargetFunctions, FoundryAsserts {
    function setUp() public {
        setup();
    }
}
