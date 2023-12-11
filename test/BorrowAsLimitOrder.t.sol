// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract BorrowAsLimitOrderTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook() public {
        _deposit(alice, 100e18, 100e18);
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e4;
        rates[1] = 1.02e4;
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _borrowAsLimitOrder(alice, 50e18, timeBuckets, rates);
        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }
}
