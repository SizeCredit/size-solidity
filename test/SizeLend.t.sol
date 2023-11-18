// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

contract SizeLendTest is BaseTest {
    function test_SizeLend_lendAsLimitOrder_increases_loan_offers() public {
        vm.startPrank(alice);

        assertEq(size.activeLoanOffers(), 0);
        size.lendAsLimitOrder(100e18, 12, YieldCurveLibrary.getFlatRate(0.03e18, 12));
        assertEq(size.activeLoanOffers(), 1);
    }
}
