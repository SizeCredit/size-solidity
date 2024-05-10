// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LendAsLimitOrderValidationTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsLimitOrder_validation() public {
        _deposit(alice, usdc, 100e6);
        uint256 maxDueDate = 12 days;
        uint256[] memory marketRateMultipliers = new uint256[](2);
        uint256[] memory maturities = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory rates1 = new int256[](1);
        rates1[0] = 1.01e18;

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: rates1
                })
            })
        );

        int256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: empty
                })
            })
        );

        int256[] memory aprs = new int256[](2);
        aprs[0] = 1.01e18;
        aprs[1] = 1.02e18;

        maturities[0] = 2 days;
        maturities[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.MATURITIES_NOT_STRICTLY_INCREASING.selector));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: aprs
                })
            })
        );

        maturities[0] = 6 hours;
        maturities[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.MATURITY_BELOW_MINIMUM_MATURITY.selector, 6 hours, 24 hours));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: maxDueDate,
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: aprs
                })
            })
        );

        maturities[0] = 1 days;
        maturities[1] = 2 days;

        vm.warp(3);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_MAX_DUE_DATE.selector, 2));
        size.lendAsLimitOrder(
            LendAsLimitOrderParams({
                maxDueDate: 2,
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: aprs
                })
            })
        );
    }
}
