// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BorrowOffer, LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {Test} from "forge-std/Test.sol";

contract OfferLibraryTest is Test {
    function test_OfferLibrary_isNull() public {
        LoanOffer memory l;
        assertEq(OfferLibrary.isNull(l), true);

        BorrowOffer memory b;
        assertEq(OfferLibrary.isNull(b), true);
    }
}
