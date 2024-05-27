// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract SizeViewTest is BaseTest {
    function test_SizeView_getBorrowOfferAPR_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getBorrowOfferAPR(alice, block.timestamp);

        _sellCreditLimitOrder(alice, YieldCurveHelper.marketCurve());

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, block.timestamp - 1));
        size.getBorrowOfferAPR(alice, block.timestamp - 1);
    }

    function test_SizeView_getLoanOfferAPR_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getLoanOfferAPR(alice, block.timestamp);

        _buyCreditLimitOrder(alice, block.timestamp + 365 days, 1e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, block.timestamp - 1));
        size.getLoanOfferAPR(alice, block.timestamp - 1);
    }

    function test_SizeView_getLoanStatus() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_POSITION_ID.selector, 0));
        size.getLoanStatus(0);
    }
}
