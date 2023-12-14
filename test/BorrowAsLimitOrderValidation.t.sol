// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";

import {BorrowOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";

import {BorrowAsLimitOrderParams} from "@src/libraries/actions/BorrowAsLimitOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BorrowAsLimitOrderValidationTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_BorrowAsLimitOrderValidation() public {
        _deposit(alice, 100e18, 100e18);
        uint256 maxAmount = 100e18;
        uint256[] memory timeBuckets = new uint256[](2);
        timeBuckets[0] = 1 days;
        timeBuckets[1] = 2 days;
        uint256[] memory rates1 = new uint256[](1);
        rates1[0] = 1.01e4;

        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({
                maxAmount: maxAmount,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates1})
            })
        );

        uint256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({
                maxAmount: maxAmount,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: empty})
            })
        );

        uint256[] memory rates = new uint256[](2);
        rates[0] = 1.01e4;
        rates[1] = 1.02e4;
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_AMOUNT.selector));
        size.borrowAsLimitOrder(
            BorrowAsLimitOrderParams({
                maxAmount: 0,
                curveRelativeTime: YieldCurve({timeBuckets: timeBuckets, rates: rates})
            })
        );
    }
}
