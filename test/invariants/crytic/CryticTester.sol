// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CryticAsserts} from "@chimera/CryticAsserts.sol";

import {SetupLocal} from "@test/invariants/SetupLocal.sol";
import {TargetFunctions} from "@test/invariants/TargetFunctions.sol";

// echidna test/invariants/crytic/CryticTester.sol --contract CryticTester --config echidna.yaml
// medusa fuzz
contract CryticTester is TargetFunctions, SetupLocal, CryticAsserts {
    constructor() {
        setup();
    }
}
