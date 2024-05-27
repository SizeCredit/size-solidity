// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {BorrowOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {SellCreditLimitParams} from "@src/libraries/fixed/actions/SellCreditLimit.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SellCreditLimitValidationTest is BaseTest {
    using OfferLibrary for BorrowOffer;

    function test_SellCreditLimit_validation() public {
        _deposit(alice, weth, 100e18);
        uint256[] memory maturities = new uint256[](2);
        uint256[] memory marketRateMultipliers = new uint256[](2);
        maturities[0] = 1 days;
        maturities[1] = 2 days;
        int256[] memory rates1 = new int256[](1);
        rates1[0] = 1.01e18;

        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        size.sellCreditLimit(
            SellCreditLimitParams({
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: rates1
                })
            })
        );

        int256[] memory empty;

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ARRAY.selector));
        size.sellCreditLimit(
            SellCreditLimitParams({
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
        size.sellCreditLimit(
            SellCreditLimitParams({
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: aprs
                })
            })
        );

        maturities[0] = 6 hours;
        maturities[1] = 1 days;
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_BELOW_MINIMUM_TENOR.selector, 6 hours, 24 hours));
        size.sellCreditLimit(
            SellCreditLimitParams({
                curveRelativeTime: YieldCurve({
                    maturities: maturities,
                    marketRateMultipliers: marketRateMultipliers,
                    aprs: aprs
                })
            })
        );
    }
}
