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

    modifier checkProperties() {
        _;
        assertTrue(property_LOAN(), LOAN);
        assertTrue(property_UNDERWATER(), UNDERWATER);
        assertTrue(property_TOKENS(), TOKENS);
        assertTrue(property_SOLVENCY(), SOLVENCY);
        assertTrue(property_FEES(), FEES);
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

    function test_CryticToFoundry_01() public checkProperties {
        deposit(address(0x1fffffffe), 4);
    }

    function test_CryticToFoundry_02() public checkProperties {
        deposit(0xe11bcd2D4941AA8648b2c1D5e470D915c05CC603, 73899321702418552725334123008022);
    }

    function test_CryticToFoundry_03() public checkProperties {
        deposit(
            0x64Cf4A4613A8E4C56e81D52Bc814dF43fB6Ac75d,
            115792089237316195423570985008687907853269984665640564039457584007913129639932
        );
        setLiquidityIndex(115792089237316195423570985008687907853269984665640564039457584007913129639934, 3);
        property_TOKENS();
    }

    function test_CryticToFoundry_04() public checkProperties {
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

    function test_CryticToFoundry_05() public checkProperties {
        buyCreditLimit(11991443917530647420774, 3);
        updateConfig(46481846931432401445888159185091847000024858619702667713489049788141731, 10385809);
        sellCreditMarket(address(0x0), 0, 255950761242656429883442036947612123737672341259439413588850, 605956, false);
    }

    function test_CryticToFoundry_06() public checkProperties {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(627253, 3);
        deposit(address(0x0), 277173003316296293927);
        sellCreditMarket(address(0x0), 0, 8364335607247948167695496674283411717220691865669214800699, 605956, false);
        sellCreditMarket(
            address(0x0), 0, 17217729, 8089560715892272342403863296103953896773539712036938251612026, false
        );
    }

    function test_CryticToFoundry_07() public checkProperties {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(607378, 3);
        deposit(address(0x0), 0);
        sellCreditMarket(address(0x0), 0, 51480107806899221988161571891687667782123974947, 605800, false);
    }

    function test_CryticToFoundry_08() public checkProperties {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(33384594783, 3);
        deposit(address(0x0), 9149686054833342031943887452235404424320189628012854416084);
        sellCreditMarket(address(0x0), 0, 76670736836295901040121558978319704354886418228159, 605956, false);
        updateConfig(
            3760962939656215923299540111674614985114988683331511536101273177295541472406,
            1351984053017908459298206846056544696633775644724223889079548121117739566
        );
    }

    function test_CryticToFoundry_09() public checkProperties {
        deposit(address(0x0), 0);
        buyCreditLimit(9833424, 3);
        deposit(address(0xdeadbeef), 0);
        sellCreditMarket(address(0x0), 0, 8619394271467961222384696387135150563289845341249406, 605956, false);
        updateConfig(
            75179511033151027828868770842695232488786737867983491430045723932720,
            45010057102343396084279157905530369481918485656143595717139543211986
        );
        vm.warp(block.timestamp + 628511);
        vm.roll(block.number + 1);
        liquidate(9160696969654105850476192767932488555016512416, 6340719317421488883471319518882382505308196);
    }

    function test_CryticToFoundry_10() public checkProperties {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(615772, 3);
        deposit(address(0x0), 0);
        sellCreditMarket(address(0x0), 0, 147058977595679525986423272625702, 605956, false);
        compensate(0, 90537930272888273525, 7551184);
    }
}
