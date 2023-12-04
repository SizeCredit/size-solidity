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

import {Errors} from "@src/libraries/Errors.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract LendAsLimitOrderValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsLimitOrderValidation() public {
        _deposit(alice, address(usdc), 100e6);
        uint256 maxAmount = 100e18;
        uint256 maxDueDate = 12;
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates1 = new uint256[](1);
        rates1[0] = 1.01e4;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.lendAsLimitOrder(maxAmount, maxDueDate, timeBuckets, rates1);

        uint256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.lendAsLimitOrder(maxAmount, maxDueDate, timeBuckets, empty);

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e4;
        rates[1] = 1.02e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.lendAsLimitOrder(0, maxDueDate, timeBuckets, rates);

        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_FREE_CASH.selector, 100e18, 100e18 + 1));
        size.lendAsLimitOrder(maxAmount + 1, maxDueDate, timeBuckets, rates);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_MAX_DUE_DATE.selector));
        size.lendAsLimitOrder(maxAmount, 0, timeBuckets, rates);

        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_MAX_DUE_DATE.selector, 2));
        size.lendAsLimitOrder(maxAmount, 2, timeBuckets, rates);
    }
}
