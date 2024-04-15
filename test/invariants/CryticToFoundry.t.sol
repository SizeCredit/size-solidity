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

    function test_CryticToFoundry_deposit_simple() public {
        deposit(address(0x1fffffffe), 4);
    }

    function test_CryticToFoundry_borrowAsMarketOrder_revert() public {
        borrowAsMarketOrder(
            address(0x0),
            7258293203459773444856724049963184653257961299884193721136437814788,
            0,
            false,
            366345095952906084925779668485935966503026202637968315265487852519,
            1145273
        );
    }

    function test_CryticToFoundry_lendAsMarketOrder_revert() public {
        lendAsMarketOrder(
            address(0x0),
            746002483745924504617129495929832196658088450097934991098756,
            210919919733701751509321278657510603028624473839246302366164,
            false
        );
    }

    function test_CryticToFoundry_borrowAsLimitOrder_revert() public {
        borrowAsLimitOrder(0, 0);
    }
}
