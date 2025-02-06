// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {CopyLimitOrder} from "@src/libraries/OfferLibrary.sol";
import {OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract CopyLimitOrdersTest is BaseTest {
    CopyLimitOrder private nullCopy;
    CopyLimitOrder private fullCopy =
        CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});

    function test_CopyLimitOrders_copyLimitOrders_copy_limit_orders() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        uint256 borrowOfferAPR = size.getBorrowOfferAPR(bob, 30 days);
        assertEq(borrowOfferAPR, 0.05e18);

        uint256 loanOfferAPR = size.getLoanOfferAPR(bob, 60 days);
        assertEq(loanOfferAPR, 0.08e18);

        _copyLimitOrders(
            alice,
            bob,
            CopyLimitOrder({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0,
                maxAPR: type(uint256).max,
                offsetAPR: 0
            }),
            CopyLimitOrder({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0,
                maxAPR: type(uint256).max,
                offsetAPR: 0
            })
        );

        assertEq(size.getBorrowOfferAPR(alice, 30 days), borrowOfferAPR);
        assertEq(size.getLoanOfferAPR(alice, 60 days), loanOfferAPR);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_only_loan_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        _copyLimitOrders(alice, bob, fullCopy, nullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getBorrowOfferAPR(alice, 30 days);

        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.12e18));
        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.12e18);

        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_only_borrow_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        _copyLimitOrders(alice, bob, nullCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getLoanOfferAPR(alice, 60 days);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.07e18));
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.07e18);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);
    }

    function test_CopyLimitOrders_copyLimitOrders_reset_copy() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        _copyLimitOrders(alice, bob, fullCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);

        _copyLimitOrders(alice, bob, nullCopy, nullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getBorrowOfferAPR(alice, 30 days);
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        size.getLoanOfferAPR(alice, 60 days);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_limit_orders_tenor_boundaries() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.02e18), uint256(15 days), uint256(0.07e18))
        );

        CopyLimitOrder memory copyLoanOffer =
            CopyLimitOrder({minTenor: 4 days, maxTenor: 6 days, minAPR: 0.05e18, maxAPR: 0.1e18, offsetAPR: 0});

        CopyLimitOrder memory copyBorrowOffer =
            CopyLimitOrder({minTenor: 2 days, maxTenor: 10 days, minAPR: 0.01e18, maxAPR: 0.03e18, offsetAPR: 0});

        _copyLimitOrders(alice, bob, copyLoanOffer, copyBorrowOffer);

        assertEq(size.getLoanOfferAPR(bob, 3 days), 0.03e18);
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 4 days, 6 days));
        size.getLoanOfferAPR(alice, 3 days);

        assertEq(size.getBorrowOfferAPR(bob, 15 days), 0.07e18);
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 2 days, 10 days));
        size.getBorrowOfferAPR(alice, 15 days);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_limit_orders_apr_boundaries() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.02e18), uint256(15 days), uint256(0.3e18))
        );

        CopyLimitOrder memory copyLoanOffer =
            CopyLimitOrder({minTenor: 4 days, maxTenor: 6 days, minAPR: 0.05e18, maxAPR: 0.06e18, offsetAPR: 0});

        CopyLimitOrder memory copyBorrowOffer =
            CopyLimitOrder({minTenor: 2 days, maxTenor: 10 days, minAPR: 0.01e18, maxAPR: 0.03e18, offsetAPR: 0});

        _copyLimitOrders(alice, bob, copyLoanOffer, copyBorrowOffer);

        assertEq(size.getLoanOfferAPR(alice, 4 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, 6 days), 0.06e18);

        assertEq(size.getBorrowOfferAPR(alice, 2 days), 0.03e18);
        assertEq(size.getBorrowOfferAPR(alice, 10 days), 0.03e18);
    }

    function testFuzz_CopyLimitOrders_copyLimitOrders_invariants(
        address copyAddress,
        uint256 minTenorLoanOffer,
        uint256 maxTenorLoanOffer,
        uint256 minAPRLoanOffer,
        uint256 maxAPRLoanOffer,
        uint256 minTenorBorrowOffer,
        uint256 maxTenorBorrowOffer,
        uint256 minAPRBorrowOffer,
        uint256 maxAPRBorrowOffer
    ) public {
        CopyLimitOrder memory copyLoanOffer = CopyLimitOrder({
            minTenor: minTenorLoanOffer,
            maxTenor: maxTenorLoanOffer,
            minAPR: minAPRLoanOffer,
            maxAPR: maxAPRLoanOffer,
            offsetAPR: 0
        });
        CopyLimitOrder memory copyBorrowOffer = CopyLimitOrder({
            minTenor: minTenorBorrowOffer,
            maxTenor: maxTenorBorrowOffer,
            minAPR: minAPRBorrowOffer,
            maxAPR: maxAPRBorrowOffer,
            offsetAPR: 0
        });
        _copyLimitOrders(alice, copyAddress, copyLoanOffer, copyBorrowOffer);

        if (copyAddress != address(0)) {
            assertTrue(OfferLibrary.isNull(copyLoanOffer) || OfferLibrary.isNull(copyBorrowOffer));
        } else {
            assertTrue(OfferLibrary.isNull(copyLoanOffer) && OfferLibrary.isNull(copyBorrowOffer));
        }
    }
}
