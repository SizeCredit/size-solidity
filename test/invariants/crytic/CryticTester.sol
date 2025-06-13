// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CryticAsserts} from "@chimera/CryticAsserts.sol";

import {ERC20TargetFunctions} from "@test/invariants/ERC20TargetFunctions.sol";
import {SetupLocal} from "@test/invariants/SetupLocal.sol";
import {TargetFunctions} from "@test/invariants/TargetFunctions.sol";

// echidna . --contract CryticTester --config echidna.yaml
// medusa fuzz
contract CryticTester is ERC20TargetFunctions, TargetFunctions, SetupLocal, CryticAsserts {
    constructor() {
        setup();
    }
}
