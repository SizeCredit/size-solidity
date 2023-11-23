// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract SizeLendAsLimitOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_SizeLendAsLimitOrder_lendAsLimitOrder_adds_loanOffer_to_orderbook() public {
        _deposit(alice, 100e18, 100e18);
        assertTrue(_getUsers().alice.loanOffer.isNull());
        _lendAsLimitOrder(alice, 50e18, 12, 1.01e18, 12);
        assertTrue(!_getUsers().alice.loanOffer.isNull());
    }
}
