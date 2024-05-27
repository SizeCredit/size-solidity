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
        deposit(address(0xdeadbeef), 97519241443110920792153965957231585900669055815069515145356);
        borrowAsLimitOrder(12128712494074002390108299745881041598326456919377586132);
        deposit(address(0x0), 3454149647212318342190486356561251068327670996371);
        lendAsMarketOrder(
            address(0x0),
            60424391022009849647749574289054431126887902231676242770965473014123,
            148239301701563126448758828532281561859502379527746323751158508008,
            false
        );
        withdraw(address(0xdeadbeef), 60011217022);
        setPrice(0);
        liquidate(19805366320326524679450497405684213378287519254054, 0);
    }

    function test_CryticToFoundry_03() public {
        borrowAsLimitOrder(0);
        deposit(address(0xdeadbeef), 0);
        deposit(address(0x0), 0);
        lendAsMarketOrder(address(0x0), 14883685759233386169554070446227790, 5068531, false);
        setPrice(0);
        compensate(0, 0, 0);
    }
}
