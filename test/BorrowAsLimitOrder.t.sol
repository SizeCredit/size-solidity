// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest, Vars} from "./BaseTest.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract BorrowAsLimitOrderTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrder_borrowAsLimitOrder_adds_borrowOffer_to_orderbook() public {
        _deposit(alice, 100e18, 100e18);
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e18;
        rates[1] = 1.02e18;
        assertTrue(_state().alice.user.borrowOffer.isNull());
        _borrowAsLimitOrder(alice, 50e18, timeBuckets, rates);
        assertTrue(!_state().alice.user.borrowOffer.isNull());
    }
}
