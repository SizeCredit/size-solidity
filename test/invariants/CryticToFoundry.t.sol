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
        deposit(address(0x0), 11701887785524418192436486535520000692412245628316686449426120092118080);
        deposit(address(0x0), 12228996115925641958936242891964123591486200466968002393568456449);
    }

    function test_CryticToFoundry_03() public {
        borrowAsMarketOrder(
            address(0x0),
            7258293203459773444856724049963184653257961299884193721136437814788,
            0,
            false,
            366345095952906084925779668485935966503026202637968315265487852519,
            1145273
        );
    }

    function test_CryticToFoundry_04() public {
        borrowAsMarketOrder(
            address(0x0),
            7725202679692877996630485343462647570718153008153086620608757346988788,
            141760344479030461194536569386544780250122102251231854580611460569,
            false,
            10060723714931171830825181432363087768917778531200809253315136315564,
            72448558944738478103423002238565484783696853285582469408223276149
        );
    }

    function test_CryticToFoundry_05() public {
        lendAsMarketOrder(
            address(0x0),
            746002483745924504617129495929832196658088450097934991098756,
            210919919733701751509321278657510603028624473839246302366164,
            false
        );
    }

    function test_CryticToFoundry_06() public {
        borrowAsLimitOrder(0, 0);
    }

    function test_CryticToFoundry_07() public {
        borrowAsMarketOrder(
            address(0x0),
            44106062112278176550259072435469268645208185786593270360777223910980113835938,
            665971502731129591318029932448963520627354561605072206193122862285929223052,
            false,
            172,
            11320309198371681170909016785101780121611655682407309252677041083814250665058
        );
        borrowAsLimitOrder(180162341724336367199684346413142812353046585660579162165980144773714726, 0);
    }

    function test_CryticToFoundry_08() public {
        borrowAsLimitOrder(
            271721964990697175273960543076809747505614788478823637200903,
            10159073966347838294397059243082750926436701043843
        );
    }

    function test_CryticToFoundry_09() public {
        lendAsLimitOrder(
            2292945695796549592164450490820804018997432253918124766999817995806,
            89958496982046217950265821879046247224794714169404241497294527541030,
            4
        );
    }

    function test_CryticToFoundry_10() public {
        deposit(address(0x0), 0);
        deposit(address(0xdeadbeef), 227866487717);
        borrowAsLimitOrder(2326537804497, 111659656797915429822232070065);
        lendAsMarketOrder(address(0x0), 45464213467409402180960667500828778380983547613, 5001671, false);
        borrowAsLimitOrder(0, 0);
        borrowerExit(0, address(0x0));
    }

    function test_CryticToFoundry_11() public {
        deposit(address(0xdeadbeef), 704166518704863933589202765415473518729895105787909426323098);
        deposit(address(0x0), 0);
        borrowAsLimitOrder(
            602109783645243895630345667291691265661983649350748518031541306080282,
            12207171703823816968514535352312088909180397068180298888786707269
        );
        lendAsMarketOrder(address(0x0), 1983347430666951499131913749622318018341, 5001671, false);
        vm.warp(block.timestamp + 250);
        borrowerExit(0, address(0x0));
    }
}
