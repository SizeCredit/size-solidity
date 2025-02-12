// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {CopyLimitOrder} from "@src/libraries/OfferLibrary.sol";

import {UserCopyLimitOrders} from "@src/SizeStorage.sol";
import {OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {BuyCreditMarketParams} from "@src/libraries/actions/BuyCreditMarket.sol";
import {CopyLimitOrdersParams} from "@src/libraries/actions/CopyLimitOrders.sol";
import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract CopyLimitOrdersTest is BaseTest {
    CopyLimitOrder private nullCopy;
    CopyLimitOrder private fullCopy =
        CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});

    uint256 private constant MIN = 0;
    uint256 private constant MAX = 255;

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

    function test_CopyLimitOrders_copyLimitOrders_copy_only_loan_offer() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        _copyLimitOrders(alice, bob, fullCopy, nullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, alice));
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

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, alice));
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

        _copyLimitOrders(alice, address(0), nullCopy, nullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, alice));
        size.getBorrowOfferAPR(alice, 30 days);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, alice));
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
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 3 days, 4 days, 6 days));
        size.getLoanOfferAPR(alice, 3 days);

        assertEq(size.getBorrowOfferAPR(bob, 15 days), 0.07e18);
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 15 days, 2 days, 10 days));
        size.getBorrowOfferAPR(alice, 15 days);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_limit_orders_apr_boundaries() public {
        uint256 maxDueDate = block.timestamp + 365 days;
        uint256[] memory marketRateMultipliers = new uint256[](4);
        uint256[] memory tenors = new uint256[](4);
        tenors[0] = 3 days;
        tenors[1] = 4 days;
        tenors[2] = 6 days;
        tenors[3] = 7 days;
        int256[] memory aprs = new int256[](4);
        aprs[0] = 0.03e18;
        aprs[1] = 0.04e18;
        aprs[2] = 0.12e18;
        aprs[3] = 0.15e18;

        _buyCreditLimit(
            bob, maxDueDate, YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.02e18), uint256(15 days), uint256(0.3e18))
        );

        CopyLimitOrder memory copyLoanOffer =
            CopyLimitOrder({minTenor: 4 days, maxTenor: 6 days, minAPR: 0.1e18, maxAPR: 0.11e18, offsetAPR: 0});

        CopyLimitOrder memory copyBorrowOffer =
            CopyLimitOrder({minTenor: 2 days, maxTenor: 10 days, minAPR: 0.05e18, maxAPR: 0.12e18, offsetAPR: 0});

        _copyLimitOrders(alice, bob, copyLoanOffer, copyBorrowOffer);

        assertEq(size.getLoanOfferAPR(bob, 4 days), 0.04e18);
        assertEq(size.getLoanOfferAPR(alice, 4 days), 0.1e18);

        assertEq(size.getLoanOfferAPR(bob, 6 days), 0.12e18);
        assertEq(size.getLoanOfferAPR(alice, 6 days), 0.11e18);

        assertEq(size.getBorrowOfferAPR(bob, 2 days), 0.04e18);
        assertEq(size.getBorrowOfferAPR(alice, 2 days), 0.05e18);

        assertEq(size.getBorrowOfferAPR(bob, 10 days), 0.2e18);
        assertEq(size.getBorrowOfferAPR(alice, 10 days), 0.12e18);
    }

    function testFuzz_CopyLimitOrders_copyLimitOrders_invariants(
        address copyAddress,
        CopyLimitOrder memory copyLoanOffer,
        CopyLimitOrder memory copyBorrowOffer
    ) public {
        copyAddress = address(uint160(bound(uint160(copyAddress), MIN, MAX)));
        copyLoanOffer.minTenor = bound(copyLoanOffer.minTenor, MIN, MAX);
        copyLoanOffer.maxTenor = bound(copyLoanOffer.maxTenor, MIN, MAX);
        copyLoanOffer.minAPR = bound(copyLoanOffer.minAPR, MIN, MAX);
        copyLoanOffer.maxAPR = bound(copyLoanOffer.maxAPR, MIN, MAX);
        copyLoanOffer.offsetAPR = bound(copyLoanOffer.offsetAPR, -int256(MAX), int256(MAX));
        copyBorrowOffer.minTenor = bound(copyBorrowOffer.minTenor, MIN, MAX);
        copyBorrowOffer.maxTenor = bound(copyBorrowOffer.maxTenor, MIN, MAX);
        copyBorrowOffer.minAPR = bound(copyBorrowOffer.minAPR, MIN, MAX);
        copyBorrowOffer.maxAPR = bound(copyBorrowOffer.maxAPR, MIN, MAX);
        copyBorrowOffer.offsetAPR = bound(copyBorrowOffer.offsetAPR, -int256(MAX), int256(MAX));

        vm.prank(alice);
        try size.copyLimitOrders(
            CopyLimitOrdersParams({
                copyAddress: copyAddress,
                copyLoanOffer: copyLoanOffer,
                copyBorrowOffer: copyBorrowOffer
            })
        ) {
            if (copyAddress != address(0)) {
                assertTrue(!OfferLibrary.isNull(copyLoanOffer) || !OfferLibrary.isNull(copyBorrowOffer));
            } else {
                assertTrue(OfferLibrary.isNull(copyLoanOffer) && OfferLibrary.isNull(copyBorrowOffer));
            }
        } catch (bytes memory) {}
    }

    function test_CopyLimitOrders_copyLimitOrders_loan_offer_scenario() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(
                uint256(1 days), uint256(0.02e18), uint256(10 days), uint256(0.2e18), uint256(30 days), uint256(0.25e18)
            )
        );

        CopyLimitOrder memory copyLoanOffer = CopyLimitOrder({
            minTenor: 3 days,
            maxTenor: 7 days,
            minAPR: 0.1e18,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });

        _copyLimitOrders(alice, bob, copyLoanOffer, nullCopy);

        assertEq(size.getLoanOfferAPR(alice, 3 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, 5 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, 7 days), 0.14e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 1 days, 3 days, 7 days));
        size.getLoanOfferAPR(alice, 1 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 10 days, 3 days, 7 days));
        size.getLoanOfferAPR(alice, 10 days);
    }

    function test_CopyLimitOrders_copyLimitOrders_borrow_offer_scenario() public {
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(
                uint256(1 days), uint256(0.02e18), uint256(10 days), uint256(0.2e18), uint256(30 days), uint256(0.25e18)
            )
        );

        CopyLimitOrder memory copyBorrowOffer =
            CopyLimitOrder({minTenor: 3 days, maxTenor: 15 days, minAPR: 0, maxAPR: 0.1e18, offsetAPR: 0});

        _copyLimitOrders(alice, bob, nullCopy, copyBorrowOffer);

        assertEq(size.getBorrowOfferAPR(alice, 3 days), 0.06e18);
        assertEq(size.getBorrowOfferAPR(alice, 5 days), 0.1e18);
        assertEq(size.getBorrowOfferAPR(alice, 10 days), 0.1e18);
        assertEq(size.getBorrowOfferAPR(alice, 15 days), 0.1e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 1 days, 3 days, 15 days));
        size.getBorrowOfferAPR(alice, 1 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 20 days, 3 days, 15 days));
        size.getBorrowOfferAPR(alice, 20 days);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_offer_precedence() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        _copyLimitOrders(alice, bob, fullCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);

        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.1e18));
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.15e18));

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.06e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.09e18));

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.06e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.09e18);
    }

    function test_CopyLimitOrders_copyLimitOrders_deletes_single_copy() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.08e18));

        _copyLimitOrders(alice, bob, fullCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.08e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(60 days, 0.1e18));
        _copyLimitOrders(alice, bob, nullCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.05e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.1e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.06e18));

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.06e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.1e18);
    }

    function test_CopyLimitOrders_copyLimitOrders_copy_offer_precedence_with_offset() public {
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(30 days), uint256(0.05e18), uint256(60 days), uint256(0.08e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(30 days), uint256(0.07e18), uint256(60 days), uint256(0.18e18))
        );

        CopyLimitOrder memory copyLoanOffer = CopyLimitOrder({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0.1e18,
            maxAPR: type(uint256).max,
            offsetAPR: 0.03e18
        });

        CopyLimitOrder memory copyBorrowOffer =
            CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: 0.12e18, offsetAPR: -0.01e18});

        _copyLimitOrders(alice, bob, copyLoanOffer, copyBorrowOffer);

        assertEq(size.getLoanOfferAPR(alice, 30 days), 0.1e18);
        assertEq(size.getLoanOfferAPR(alice, 60 days), 0.11e18);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.06e18);
        assertEq(size.getBorrowOfferAPR(alice, 60 days), 0.12e18);
    }

    function test_CopyLimitOrders_copyLimitOrders_can_leave_inverted_curves_with_offsetAPR() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.03e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        CopyLimitOrder memory loanCopy = CopyLimitOrder({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: -0.01e18
        });

        _copyLimitOrders(alice, bob, loanCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.03e18);
        assertEq(size.getLoanOfferAPR(alice, 30 days), 0.04e18);

        assertTrue(size.getLoanOfferAPR(alice, 30 days) > size.getBorrowOfferAPR(alice, 30 days));

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.04e18));

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.04e18);
        assertEq(size.getLoanOfferAPR(alice, 30 days), 0.04e18);

        assertTrue(!(size.getLoanOfferAPR(alice, 30 days) > size.getBorrowOfferAPR(alice, 30 days)));
    }

    function test_CopyLimitOrders_copyLimitOrders_can_leave_inverted_curves_but_market_orders_revert() public {
        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.03e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.05e18));

        CopyLimitOrder memory loanCopy = CopyLimitOrder({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: -0.01e18
        });

        _deposit(alice, weth, 1 ether);
        _deposit(alice, usdc, 3000e6);
        _copyLimitOrders(alice, bob, loanCopy, fullCopy);

        assertEq(size.getBorrowOfferAPR(alice, 30 days), 0.03e18);
        assertEq(size.getLoanOfferAPR(alice, 30 days), 0.04e18);

        _sellCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(30 days, 0.04e18));

        _deposit(candy, usdc, 2000e6);
        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 30 days, 0.04e18, 0.04e18));
        vm.prank(candy);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: RESERVED_ID,
                amount: 500e6,
                tenor: 30 days,
                minAPR: 0,
                deadline: block.timestamp + 365 days,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 30 days, 0.04e18, 0.04e18));
        vm.prank(candy);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 500e6,
                tenor: 30 days,
                maxAPR: type(uint256).max,
                deadline: block.timestamp + 365 days,
                exactAmountIn: false
            })
        );
    }

    function test_CopyLimitOrders_copyLimitOrders_copyAddress_removes_offer_then_user_defined_offer_is_still_active()
        public
    {
        _deposit(alice, usdc, 200e6);
        _deposit(candy, weth, 100e18);

        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.15e18), uint256(15 days), uint256(0.17e18))
        );

        CopyLimitOrder memory borrowCopy =
            CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: 0.1e18, offsetAPR: 0});

        _copyLimitOrders(alice, bob, fullCopy, borrowCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 5 days, 0.075e18, 0.1e18));
        vm.prank(candy);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 10e6,
                tenor: 5 days,
                maxAPR: type(uint256).max,
                deadline: block.timestamp,
                exactAmountIn: false
            })
        );

        YieldCurve memory nullCurve;
        _sellCreditLimit(bob, 0, nullCurve);

        _sellCreditMarket(candy, alice, RESERVED_ID, 10e6, 5 days, false);
    }

    function test_CopyLimitOrders_copyLimitOrders_copyAddress_updates_offer_then_user_market_order_reverts() public {
        _deposit(alice, usdc, 200e6);
        _deposit(candy, weth, 100e18);

        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(3 days), uint256(0.03e18), uint256(7 days), uint256(0.12e18))
        );
        _sellCreditLimit(
            bob,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.15e18), uint256(15 days), uint256(0.17e18))
        );

        CopyLimitOrder memory borrowCopy =
            CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: 0.1e18, offsetAPR: 0});

        _copyLimitOrders(alice, bob, fullCopy, borrowCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.MISMATCHED_CURVES.selector, alice, 5 days, 0.075e18, 0.1e18));
        vm.prank(candy);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 10e6,
                tenor: 5 days,
                maxAPR: type(uint256).max,
                deadline: block.timestamp,
                exactAmountIn: false
            })
        );

        _sellCreditLimit(
            bob,
            block.timestamp + 4 days,
            YieldCurveHelper.customCurve(uint256(1 days), uint256(0.15e18), uint256(15 days), uint256(0.17e18))
        );

        _sellCreditMarket(candy, alice, RESERVED_ID, 10e6, 5 days, false);
    }
}
