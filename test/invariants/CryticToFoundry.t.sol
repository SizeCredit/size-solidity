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
        assertTrue(property_LOAN(), LOAN);
        assertTrue(property_UNDERWATER(), UNDERWATER);
        assertTrue(property_TOKENS(), TOKENS);
        assertTrue(property_SOLVENCY(), SOLVENCY);
        assertTrue(property_FEES(), FEES);
    }

    function precondition(bool) internal virtual override(FoundryAsserts, Asserts) {
        return;
    }

    function test_CryticToFoundry_01() public {
        deposit(address(0x1fffffffe), 4);
    }

    function test_CryticToFoundry_02() public {
        deposit(0xe11bcd2D4941AA8648b2c1D5e470D915c05CC603, 73899321702418552725334123008022);
    }

    function test_CryticToFoundry_03() public {
        deposit(
            0x64Cf4A4613A8E4C56e81D52Bc814dF43fB6Ac75d,
            115792089237316195423570985008687907853269984665640564039457584007913129639932
        );
        setLiquidityIndex(115792089237316195423570985008687907853269984665640564039457584007913129639934, 3);
        property_TOKENS();
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

    function test_CryticToFoundry_06() public {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(627253, 3);
        deposit(address(0x0), 277173003316296293927);
        sellCreditMarket(address(0x0), 0, 8364335607247948167695496674283411717220691865669214800699, 605956, false);
        sellCreditMarket(
            address(0x0), 0, 17217729, 8089560715892272342403863296103953896773539712036938251612026, false
        );
    }

    function test_CryticToFoundry_07() public {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(607378, 3);
        deposit(address(0x0), 0);
        sellCreditMarket(address(0x0), 0, 51480107806899221988161571891687667782123974947, 605800, false);
    }

    function test_CryticToFoundry_08() public {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(33384594783, 3);
        deposit(address(0x0), 9149686054833342031943887452235404424320189628012854416084);
        sellCreditMarket(address(0x0), 0, 76670736836295901040121558978319704354886418228159, 605956, false);
        updateConfig(
            3760962939656215923299540111674614985114988683331511536101273177295541472406,
            1351984053017908459298206846056544696633775644724223889079548121117739566
        );
    }

    function test_CryticToFoundry_09() public {
        deposit(address(0xdeadbeef), 6650265435768735282694896341184603990418320173531048);
        sellCreditLimit(0);
        deposit(address(0x0), 14110947487286576);
        buyCreditMarket(
            address(0x0),
            0,
            1775610665997594022858846866460267459070968892247915994682862813138757916384,
            280148697151562282203777064572360693677811105921389519391554775108,
            false
        );
    }

    function test_CryticToFoundry_10() public {
        deposit(address(0xdeadbeef), 0);
        buyCreditLimit(615772, 3);
        deposit(address(0x0), 0);
        sellCreditMarket(address(0x0), 0, 147058977595679525986423272625702, 605956, false);
        compensate(0, 90537930272888273525, 7551184);
    }

    function test_CryticToFoundry_11() public {
        deposit(address(0xdeadbeef), 486987982);
        deposit(address(0x0), 542119798154271826);
        updateConfig(3476689163798957933627285661408434842686568751617897946215078674744880122, 1);
        sellCreditLimit(0);
        setLiquidityIndex(1, 0);
        buyCreditMarket(
            address(0x0),
            0,
            560297479045200601233239408702471290199352436977548093015982641843298539,
            22576319848627412381195622757383666471949398566030438813750667,
            false
        );
    }

    function test_CryticToFoundry_12() public {
        deposit(address(0xdeadbeef), 481797977);
        sellCreditLimit(0);
        deposit(address(0x0), 542722934120754506);
        buyCreditMarket(
            address(0x0),
            0,
            308038948465724683836823477037869565199260835768169178060056385273936037,
            22576319848627412381195622757383666471949398566030438813750667,
            false
        );
    }

    function test_CryticToFoundry_13() public {
        deposit(address(0x0), 309646366057719218);
        buyCreditLimit(3660, 125725079549898127780212690292168332883405948303381474);
        deposit(address(0xdeadbeef), 49671462709254420677446753);
        sellCreditMarket(address(0x0), 0, 122457266127183160707598484974950339, 3613, false);
    }

    function test_CryticToFoundry_14() public {
        deposit(address(0xdeadbeef), 486987982);
        deposit(address(0x0), 542119798154271826);
        updateConfig(3476689163798957933627285661408434842686568751617897946215078674744880122, 1);
        sellCreditLimit(0);
        setLiquidityIndex(1, 0);
        buyCreditMarket(
            address(0x0),
            0,
            560297479045200601233239408702471290199352436977548093015982641843298539,
            22576319848627412381195622757383666471949398566030438813750667,
            false
        );
    }
}
