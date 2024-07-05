// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CryticAsserts} from "@chimera/CryticAsserts.sol";
import {TargetFunctions} from "@test/invariants/TargetFunctions.sol";

// echidna . --contract CryticTester --config echidna.yaml
// medusa fuzz
contract CryticTester is TargetFunctions, CryticAsserts {
    constructor() {
        setup();
    }
}
