// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CryticAsserts} from "@chimera/CryticAsserts.sol";
import {Deploy} from "@script/Deploy.sol";
import {VaultsTargetFunctions} from "@test/local/v1.8/invariants/VaultsTargetFunctions.sol";

// echidna . --contract CryticVaultsTester --config echidna.yaml
// medusa fuzz
contract CryticVaultsTester is CryticAsserts, Deploy, VaultsTargetFunctions {
    constructor() {
        setup();
    }
}
