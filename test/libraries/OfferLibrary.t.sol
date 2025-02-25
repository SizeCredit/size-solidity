// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LimitOrder, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {Test} from "forge-std/Test.sol";

contract OfferLibraryTest is Test {
    function test_OfferLibrary_isNull() public pure {
        LimitOrder memory l;
        assertEq(OfferLibrary.isNull(l), true);

        LimitOrder memory b;
        assertEq(OfferLibrary.isNull(b), true);
    }
}
