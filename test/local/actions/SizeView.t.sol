// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract SizeViewTest is BaseTest {
    function test_SizeView_getBorrowOfferAPR_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getBorrowOfferAPR(alice, block.timestamp);

        _sellCreditLimit(alice, YieldCurveHelper.marketCurve());

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_TENOR.selector));
        size.getBorrowOfferAPR(alice, 0);
    }

    function test_SizeView_getLoanOfferAPR_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getLoanOfferAPR(alice, block.timestamp);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_TENOR.selector));
        size.getLoanOfferAPR(alice, 0);
    }

    function test_SizeView_getLoanStatus() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_POSITION_ID.selector, 0));
        size.getLoanStatus(0);
    }

    function test_SizeView_getSwapFee_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_TENOR.selector));
        size.getSwapFee(100e6, 0);
    }

    function test_SizeView_isDebtPositionId_no_loans() public {
        assertEq(size.isDebtPositionId(0), false);
    }
}
