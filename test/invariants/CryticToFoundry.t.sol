// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";

import {Asserts} from "@chimera/Asserts.sol";
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

    function precondition(bool) internal virtual override(FoundryAsserts, Asserts) {
        return;
    }

    function test_CryticToFoundry_01() public {
        deposit(address(0x1fffffffe), 4);
    }

    function test_CryticToFoundry_02() public {
        deposit(0xe11bcd2D4941AA8648b2c1D5e470D915c05CC603, 73899321702418552725334123008022);
        invariant_TOKENS();
    }

    function test_CryticToFoundry_03() public {
        deposit(
            0x64Cf4A4613A8E4C56e81D52Bc814dF43fB6Ac75d,
            115792089237316195423570985008687907853269984665640564039457584007913129639932
        );
        setLiquidityIndex(115792089237316195423570985008687907853269984665640564039457584007913129639934, 3);
        invariant_TOKENS();
    }
}
