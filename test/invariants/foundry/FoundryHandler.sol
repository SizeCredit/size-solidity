// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";

import {SetupLocal} from "@test/invariants/SetupLocal.sol";
import {TargetFunctions} from "@test/invariants/TargetFunctions.sol";

contract FoundryHandler is TargetFunctions, SetupLocal, FoundryAsserts {
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
