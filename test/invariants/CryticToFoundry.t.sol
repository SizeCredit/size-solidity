// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {TargetFunctions} from "./TargetFunctions.sol";
import {FoundryAsserts} from "@chimera/FoundryAsserts.sol";
import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

contract CryticToFoundry is Test, TargetFunctions, FoundryAsserts {
    function setUp() public {
        vm.deal(address(USER1), 100e18);
        vm.deal(address(USER2), 100e18);
        vm.deal(address(USER3), 100e18);

        setup();

        sender = USER1;
    }

    modifier getSender() override {
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

        t(invariant_SOLVENCY_01(), SOLVENCY_01);
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

        assertTrue(invariant_SOLVENCY_02(), SOLVENCY_02);
    }

    function test_CryticToFoundry_07() public {
        // CryticTester.deposit(0xdeadbeef,11904803604958988569572617684222248)
        // CryticTester.setLiquidityIndex(5010010177153568)
        // CryticTester.withdraw(0xdeadbeef,36435084)

        deposit(address(0xdeadbeef), 11904803604958988569572617684222248);
        setLiquidityIndex(5010010177153568);
        console.log(variablePool.getReserveNormalizedIncome(address(usdc)));
        withdraw(address(0xdeadbeef), 36435084);
    }

    function test_CryticToFoundry_08() public {
        // CryticTester.setLiquidityIndex(39230582154854410937060535)
        // CryticTester.deposit(0xdeadbeef,12706084137082100291738998232343986780437457837920)

        setLiquidityIndex(39230582154854410937060535);
        deposit(address(0xdeadbeef), 12706084137082100291738998232343986780437457837920);
    }
}
