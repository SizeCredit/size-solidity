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

        vm.warp(1524785992);
        vm.roll(4370000);

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
        property_TOKENS();
    }

    function test_CryticToFoundry_03() public {
        deposit(
            0x64Cf4A4613A8E4C56e81D52Bc814dF43fB6Ac75d,
            115792089237316195423570985008687907853269984665640564039457584007913129639932
        );
        setLiquidityIndex(115792089237316195423570985008687907853269984665640564039457584007913129639934, 3);
        property_TOKENS();
    }

    function test_CryticToFoundry_06() public {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(627253, 3);
        deposit(address(0x0), 277173003316296293927);
        sellCreditMarket(address(0x0), 0, 8364335607247948167695496674283411717220691865669214800699, 605956, false);
        sellCreditMarket(
            address(0x0), 0, 17217729, 8089560715892272342403863296103953896773539712036938251612026, false
        );
    }

    function test_CryticToFoundry_04() public {
        buyCreditLimit(61610961792943, 745722042769143156660);
        updateConfig(34427929482916198936384567379399524978565095668324743502528967604624539, 84308633);
        sellCreditMarket(
            address(0x0),
            2930762529385342386013132128768,
            2349033066314694823075402460322659131477895613343804352970665415788,
            481460843976435882299533915351829538674179421703829407269908408881959677635,
            false
        );
    }

    function test_CryticToFoundry_05() public {
        buyCreditLimit(11991443917530647420774, 3);
        updateConfig(46481846931432401445888159185091847000024858619702667713489049788141731, 10385809);
        sellCreditMarket(address(0x0), 0, 255950761242656429883442036947612123737672341259439413588850, 605956, false);
    }
}
