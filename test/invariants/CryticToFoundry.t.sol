// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

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

    function test_CryticToFoundry_01() public {
        deposit(address(0x1fffffffe), 4);
    }

    function test_CryticToFoundry_02() public {
        deposit(address(0xdeadbeef), 0);
        deposit(address(0x0), 0);
        borrowAsLimitOrder(285, 806924974754);
        lendAsMarketOrder(address(0x0), 1374976, 5079504, false);
        lendAsMarketOrder(address(0x0), 4555056874391068022, 5001671, false);
        setPrice(0);
        repay(0);
    }
}
