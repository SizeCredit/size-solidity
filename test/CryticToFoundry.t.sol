// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {TargetFunctions} from "@src/invariants/TargetFunctions.sol";
import {Logger} from "@test/Logger.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts, Logger {
    function setUp() public {
        vm.deal(address(USER1), 100e18);
        vm.deal(address(USER2), 100e18);
        vm.deal(address(USER3), 100e18);

        vm.warp(1524785992);

        setup();

        sender = USER1;
    }

    modifier getSender() override {
        _;
        assertTrue(invariant_LOAN_01(), LOAN_01);
        assertTrue(invariant_UNDERWATER_01(), UNDERWATER_01);
        assertTrue(invariant_TOKENS_01(), TOKENS_01);
        assertTrue(invariant_SOLVENCY(), SOLVENCY);
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

    function test_CryticToFoundry_03() public {
        // CryticTester.deposit(0x0,0) from: 0x0000000000000000000000000000000000010000 Time delay: 322253 seconds Block delay: 97
        // CryticTester.deposit(0x19,259200) from: 0x0000000000000000000000000000000000030000 Time delay: 43114 seconds Block delay: 34720
        // CryticTester.borrowAsLimitOrder(24,24844501279188594811050686) from: 0x0000000000000000000000000000000000010000 Time delay: 103251 seconds Block delay: 8452
        // CryticTester.lendAsMarketOrder(0x2fffffffd,50615909404129645970636918760385849336880119737366532954759566057852349967088,110595804659557629263599264716938215899314735388211371324492753902571693562367,false) from: 0x0000000000000000000000000000000000030000 Time delay: 531976 seconds Block delay: 2
        // CryticTester.deposit(0xffffffff,21853951502790869107965942217679516996955097091935548379402511718674642168266) from: 0x0000000000000000000000000000000000020000 Time delay: 237843 seconds Block delay: 56264
        // CryticTester.setPrice(0) from: 0x0000000000000000000000000000000000010000 Time delay: 588255 seconds Block delay: 31205
        // CryticTester.liquidate(0,500) from: 0x0000000000000000000000000000000000020000 Time delay: 28 seconds Block delay: 14913

        vm.warp(block.timestamp + 322253);
        sender = USER1;
        deposit(address(0x0), 0);

        vm.warp(block.timestamp + 43114);
        sender = USER3;
        deposit(address(0x19), 259200);

        vm.warp(block.timestamp + 103251);
        sender = USER1;
        borrowAsLimitOrder(24, 24844501279188594811050686);

        vm.warp(block.timestamp + 531976);
        sender = USER3;
        lendAsMarketOrder(
            address(0x2fffffffd),
            50615909404129645970636918760385849336880119737366532954759566057852349967088,
            110595804659557629263599264716938215899314735388211371324492753902571693562367,
            false
        );

        vm.warp(block.timestamp + 237843);
        sender = USER2;
        deposit(address(0xffffffff), 21853951502790869107965942217679516996955097091935548379402511718674642168266);

        vm.warp(block.timestamp + 588255);
        sender = USER1;
        setPrice(0);

        vm.warp(block.timestamp + 28 seconds);
        sender = USER2;
        liquidate(0, 500);
    }

    function test_CryticToFoundry_04() public {
        // CryticTester.deposit(0xdeadbeef,0)
        // CryticTester.deposit(0x0,0)
        // CryticTester.borrowAsLimitOrder(0,0)
        // CryticTester.lendAsMarketOrder(0x0,762433799931065407245075044326762306,5003750,false)
        // CryticTester.repay(0)
        deposit(address(0xdeadbeef), 0);
        deposit(address(0x0), 0);
        borrowAsLimitOrder(0, 0);
        lendAsMarketOrder(address(0x0), 762433799931065407245075044326762306, 5003750, false);
        repay(0);

        t(invariant_SOLVENCY(), SOLVENCY_01);
    }

    function test_CryticToFoundry_05() public {
        // CryticTester.deposit(0x0,212133831549)
        // CryticTester.deposit(0xdeadbeef,0)
        // CryticTester.borrowAsLimitOrder(102813898223605900483909,77570742887577467430810329579079414851392708576767)
        // CryticTester.lendAsMarketOrder(0x0,606338,420030534754023700037381865,false)
        // *wait* Time delay: 437811 seconds Block delay: 1584
        // *wait* Time delay: 174779 seconds Block delay: 5
        // CryticTester.liquidate(115792089237316195423570985008687907853269984665640564039457584007913129639935,0)

        deposit(address(0x0), 212133831549);
        deposit(address(0xdeadbeef), 0);
        borrowAsLimitOrder(102813898223605900483909, 77570742887577467430810329579079414851392708576767);
        lendAsMarketOrder(address(0x0), 606338, 420030534754023700037381865, false);

        vm.warp(block.timestamp + 437811);
        vm.warp(block.timestamp + 174779);

        liquidate(115792089237316195423570985008687907853269984665640564039457584007913129639935, 0);
    }

    function test_CryticToFoundry_06() public {
        // CryticTester.deposit(0x0,0)
        // CryticTester.deposit(0xdeadbeef,0)
        // CryticTester.borrowAsLimitOrder(126916350406155650612,113930643638645882964219268883550108643297450389)
        // CryticTester.lendAsMarketOrder(0x0,606338,5144481794334966487245181,false)
        // *wait* Time delay: 437683 seconds Block delay: 875
        // *wait* Time delay: 174779 seconds Block delay: 5
        // CryticTester.liquidate(13634972797739814676263703624190704207393075217923416096395985069656,0)

        deposit(address(0x0), 0);
        deposit(address(0xdeadbeef), 0);
        borrowAsLimitOrder(126916350406155650612, 113930643638645882964219268883550108643297450389);
        lendAsMarketOrder(address(0x0), 606338, 5144481794334966487245181, false);

        vm.warp(block.timestamp + 437683);
        vm.warp(block.timestamp + 174779);

        liquidate(13634972797739814676263703624190704207393075217923416096395985069656, 0);

        assertTrue(invariant_SOLVENCY(), SOLVENCY_02);
    }

    function test_CryticToFoundry_07() public {
        // CryticTester.deposit(0xdeadbeef,11904803604958988569572617684222248)
        // CryticTester.setLiquidityIndex(5010010177153568)
        // CryticTester.withdraw(0xdeadbeef,36435084)

        deposit(address(0xdeadbeef), 11904803604958988569572617684222248);
        setLiquidityIndex(5010010177153568, 0);
        console.log(variablePool.getReserveNormalizedIncome(address(usdc)));
        withdraw(address(0xdeadbeef), 36435084);
    }

    function test_CryticToFoundry_08() public {
        // CryticTester.setLiquidityIndex(39230582154854410937060535)
        // CryticTester.deposit(0xdeadbeef,12706084137082100291738998232343986780437457837920)

        setLiquidityIndex(39230582154854410937060535, 0);
        deposit(address(0xdeadbeef), 12706084137082100291738998232343986780437457837920);
    }

    function test_CryticToFoundry_09() public {
        // CryticTester.deposit(0xdeadbeef,49473334019751321612960642903970974588602648394551);
        // CryticTester.setLiquidityIndex(6861548694834691393073179238244092896040981781979822920618654793442930690)
        // CryticTester.setLiquidityIndex(1115954840427265828061058214517677221630329833090451996059356350670104)
        // CryticTester.setLiquidityIndexC9797321557023269259201900311052377384770852882561934633352)
        // CryticTester.setLiquidityIndex100091368808502191030772197116316725877531905)
        // CryticTester.deposit(0x0,0)

        deposit(address(0xdeadbeef), 49473334019751321612960642903970974588602648394551);
        setLiquidityIndex(6861548694834691393073179238244092896040981781979822920618654793442930690, 0);
        setLiquidityIndex(1115954840427265828061058214517677221630329833090451996059356350670104, 0);
        setLiquidityIndex(9797321557023269259201900311052377384770852882561934633352, 0);
        setLiquidityIndex(100091368808502191030772197116316725877531905, 0);
        deposit(address(0x0), 0);
    }

    function test_CryticToFoundry_11() public {
        deposit(0xe4866b585C63116092e5d0569757207D035016B7, 3);
        setLiquidityIndex(115792089237316195423570985008687907853269984665640564039457584007913129639935, 0);
        t(invariant_TOKENS_01(), TOKENS_01);
    }

    function test_CryticToFoundry_12() public {
        deposit(0x470c8B323b89c05bbB0F2a85d733Cc7004883d14, 45);
        withdraw(
            0x00000000000000000000000000000000002FEF7C,
            70880928519027259232681487313122362188527844215780522898084047764600190669520
        );
    }

    function test_CryticToFoundry_13() public {
        deposit(0x0000000000000000000000000001fffFfFFFFfff, 131072);
    }

    function test_CryticToFoundry_14() public {
        // CryticTester.deposit(0x0,0)
        // CryticTester.borrowAsLimitOrder(0,0)
        // CryticTester.deposit(0xdeadbeef,0)
        // CryticTester.lendAsMarketOrder(0x0,2592121,11143629335882188948651649360494736035151267490671837874019124983,false)
        // CryticTester.setLiquidityIndex(277630701152545447322873122819513599548980,0)
        // CryticTester.repay(0)
        // CryticTester.claim(0)

        deposit(address(0x0), 0);
        borrowAsLimitOrder(0, 0);
        deposit(address(0xdeadbeef), 0);
        lendAsMarketOrder(
            address(0x0), 2592121, 11143629335882188948651649360494736035151267490671837874019124983, false
        );
        setLiquidityIndex(277630701152545447322873122819513599548980, 0);
        repay(0);
        claim(0);
    }

    function test_CryticToFoundry_15() public {
        // CryticTester.deposit(0x0,0)
        // CryticTester.deposit(0xdeadbeef,0)
        // CryticTester.borrowAsLimitOrder(0,0)
        // CryticTester.lendAsMarketOrder(0x0,9806895064332224580019607489522738393543497761842171770419912728544585,415249588682284395970195958922345498355669666758998623004819085530327,false)
        // CryticTester.setLiquidityIndex(85018487267919046903678918019124862169067773686369510826691872189528,1687617916531946288552279744779149023221334453635590351)
        // CryticTester.lendAsLimitOrder(0,4658037204486198634009478739560699702150171958228383770907791,19964779482548510850982438244306504693449912630871743221673749602)
        // CryticTester.borrowAsMarketOrder(0x0,912287570375167406028518890095717184787892638622143615024853699854314,751752031956724358869640862547786345459427492877661078173001131,false,42600753123538819703737021163820107704714195044143068644555241190957,458206780595871901084838206323078719874994744)
        // CryticTester.repay(0)
        // CryticTester.claim(1)
        // CryticTester.claim(0)

        deposit(address(0x0), 0);
        deposit(address(0xdeadbeef), 0);
        borrowAsLimitOrder(0, 0);
        lendAsMarketOrder(
            address(0x0),
            9806895064332224580019607489522738393543497761842171770419912728544585,
            415249588682284395970195958922345498355669666758998623004819085530327,
            false
        );
        setLiquidityIndex(
            85018487267919046903678918019124862169067773686369510826691872189528,
            1687617916531946288552279744779149023221334453635590351
        );
        lendAsLimitOrder(
            0,
            4658037204486198634009478739560699702150171958228383770907791,
            19964779482548510850982438244306504693449912630871743221673749602
        );
        borrowAsMarketOrder(
            address(0x0),
            912287570375167406028518890095717184787892638622143615024853699854314,
            751752031956724358869640862547786345459427492877661078173001131,
            false,
            42600753123538819703737021163820107704714195044143068644555241190957,
            458206780595871901084838206323078719874994744
        );
        repay(0);
        claim(1);
        claim(0);
    }

    function test_CryticToFoundry_16() public {
        deposit(address(0x0), 0);
        deposit(address(0xdeadbeef), 17556450);
        borrowAsLimitOrder(0, 0);
        lendAsMarketOrder(address(0x0), 34586724, 340702833386891, false);
        setPrice(0);
        selfLiquidate(0);
    }

    function test_CryticToFoundry_17() public {
        borrowAsLimitOrder(3923, 33980107616196410778387867456);
        deposit(address(0x0), 732122825199537941462422018675423646);
        deposit(address(0xdeadbeef), 9806867186794323686842530376938788560849587239728099175751784669);
        lendAsLimitOrder(
            79447781549944810699113766833870584964788566797165739036889,
            5361412931164146216273388061701247256400065886226598602770977361532664,
            2591415989370944547845963224582462361440156463250152112695726304
        );
        lendAsMarketOrder(
            address(0x0),
            54816393597403194571724421947054711105138502893094428491679262470238,
            8960852294637259374193817185384377159431772943768870420757276432,
            false
        );
        borrowAsMarketOrder(
            address(0x0),
            2045162979920015402344863041143534814280217120073683478928146477018216,
            179610560663284106234670294584005079325687355184849372073111686,
            false,
            14562946258144024611984026715706946855574299605338146838112013051,
            23999004492709595051890298833323480791852516236571134
        );
        setPrice(0);
        selfLiquidate(0);
    }

    function test_CryticToFoundry_18() public {
        sender = USER1;
        deposit(address(0xdeadbeef), 2935337554604700731427626315539083483);

        sender = USER1;
        borrowAsLimitOrder(
            600801365854545262038368835759703530272930, 71715183861415162426834894233833466605129944132695151891617
        );

        sender = USER1;
        deposit(address(0x0), 61);

        sender = USER1;
        lendAsMarketOrder(address(0x0), 613427, 3740013724833968908524843401169700782215646, false);

        sender = USER1;
        borrowAsLimitOrder(346391, 0);

        sender = USER3;
        vm.warp(block.timestamp + 332369 seconds);
        setPrice(0);

        sender = USER1;
        vm.warp(block.timestamp + 575483 seconds);
        liquidate(86400, 77222825025516552538440714183514879332399149171856728123139307574037976970171);

        sender = USER2;
        vm.warp(block.timestamp + 3600 seconds);
        setPrice(57605707327929105118522827675926741876259617330440577803681432669616885965533);

        sender = USER1;
        vm.warp(block.timestamp + 360624 seconds);
        lendAsLimitOrder(
            846166317695718274319437225806,
            17947932366099712616195411385067699814449504,
            735980923715527194406029760064559151
        );

        sender = USER1;
        vm.warp(block.timestamp + 172101 seconds);
        borrowAsMarketOrder(
            address(0x0),
            115792089237316195423570985008687907853269984665640564039457584007913129639933,
            29182267078413308077842556818450179317634321662124225112379110204766240,
            true,
            1030087923344035061059586578722591404763257725749975456512525,
            782873993691306723341871558552861832515519839995635503299601608118073
        );

        sender = USER2;
        vm.warp(block.timestamp + 437838 seconds);
        deposit(address(0xdeadbeef), 3679354064733996);

        sender = USER3;
        vm.warp(block.timestamp + 436727 seconds);
        deposit(address(0x1fffffffe), 115792089237316195423570985008687907853269984665640564039457584007913129639935);

        sender = USER1;
        vm.warp(block.timestamp + 136394 seconds);
        withdraw(address(0x1fffffffe), 35361702490146584512578889246347611238187798515245402027433625968893384971688);

        sender = USER2;
        vm.warp(block.timestamp + 396451 seconds);
        lendAsMarketOrder(
            address(0x1fffffffe),
            12501419888180256890749326851545346432071337754739229842004716702614102161586,
            50614988952009275764445948245886721906463958678436170056919645596780531291221,
            false
        );

        sender = USER2;
        vm.warp(block.timestamp + 440097 seconds);
        lendAsMarketOrder(
            address(0x1fffffffe),
            4369999,
            13395766943307160502121754907333510946796129068323131376008007759690239854153,
            false
        );

        sender = USER3;
        vm.warp(block.timestamp + 318197 seconds);
        borrowAsLimitOrder(8407473379090115020622155800712631285733011043173029588388563961295109829298, 4370000);

        sender = USER1;
        vm.warp(block.timestamp + 440141 seconds);
        setPrice(90768678622447573195807500409923988669401059004945670404249545528012466095060);

        sender = USER2;
        vm.warp(block.timestamp + 463587 seconds);
        liquidateWithReplacement(
            19116748911187275452518526318539152083828456420285086657569829250132385460347, 0, address(0x17)
        );
    }
}
