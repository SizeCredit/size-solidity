// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {Test} from "forge-std/Test.sol";

contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
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

    function test_BORROW_02() public {
        deposit(address(0xdeadbeef), 0);
        lendAsLimitOrder(0, 10667226, 451124);
        borrowAsMarketOrder(
            address(0x1e),
            1,
            299999999999999999,
            true,
            14221329489769958708126347564797299640365746048626527781107915342306360762091,
            47700905178432190716842576859681767948209730775316858409394951552214610302274
        );
    }
}
