// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {UserCopyLimitOrders} from "@src/SizeStorage.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {LimitOrder, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {CopyLimitOrder} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {CopyLimitOrdersOnBehalfOfParams, CopyLimitOrdersParams} from "@src/libraries/actions/CopyLimitOrders.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract AuthorizationCopyLimitOrdersTest is BaseTest {
    using OfferLibrary for LimitOrder;

    CopyLimitOrder private fullCopy =
        CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});

    function test_AuthorizationCopyLimitOrders_copyLimitOrdersOnBehalfOf() public {
        _setAuthorization(alice, bob, size, Authorization.getActionsBitmap(Action.COPY_LIMIT_ORDERS));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));
        _sellCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        vm.prank(bob);
        size.copyLimitOrdersOnBehalfOf(
            CopyLimitOrdersOnBehalfOfParams({
                params: CopyLimitOrdersParams({copyAddress: candy, copyLoanOffer: fullCopy, copyBorrowOffer: fullCopy}),
                onBehalfOf: alice
            })
        );

        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);
        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);

        UserCopyLimitOrders memory userCopyLimitOrders = size.getUserCopyLimitOrders(alice);
        assertEq(userCopyLimitOrders.copyLoanOffer.minTenor, fullCopy.minTenor);
        assertEq(userCopyLimitOrders.copyLoanOffer.maxTenor, fullCopy.maxTenor);
        assertEq(userCopyLimitOrders.copyLoanOffer.minAPR, fullCopy.minAPR);
        assertEq(userCopyLimitOrders.copyLoanOffer.maxAPR, fullCopy.maxAPR);
        assertEq(userCopyLimitOrders.copyLoanOffer.offsetAPR, fullCopy.offsetAPR);
        assertEq(userCopyLimitOrders.copyBorrowOffer.minTenor, fullCopy.minTenor);
        assertEq(userCopyLimitOrders.copyBorrowOffer.maxTenor, fullCopy.maxTenor);
        assertEq(userCopyLimitOrders.copyBorrowOffer.minAPR, fullCopy.minAPR);
        assertEq(userCopyLimitOrders.copyBorrowOffer.maxAPR, fullCopy.maxAPR);
        assertEq(userCopyLimitOrders.copyBorrowOffer.offsetAPR, fullCopy.offsetAPR);
    }

    function test_AuthorizationCopyLimitOrders_validation() public {
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));
        _sellCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        vm.expectRevert(
            abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.COPY_LIMIT_ORDERS)
        );
        vm.prank(alice);
        size.copyLimitOrdersOnBehalfOf(
            CopyLimitOrdersOnBehalfOfParams({
                params: CopyLimitOrdersParams({copyAddress: candy, copyLoanOffer: fullCopy, copyBorrowOffer: fullCopy}),
                onBehalfOf: bob
            })
        );
    }
}
