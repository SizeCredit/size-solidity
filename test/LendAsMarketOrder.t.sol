// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {BorrowOffer} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {LendAsMarketOrderParams} from "@src/libraries/actions/LendAsMarketOrder.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract LendAsMarketOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;
    using LoanLibrary for Loan;

    function test_LendAsMarketOrder_lendAsMarketOrder_transfers_to_borrower() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _borrowAsLimitOrder(alice, 100e18, 0.03e18, 12);

        uint256 faceValue = 10e18;
        uint256 dueDate = 12;
        uint256 amountIn = Math.mulDivUp(faceValue, PERCENT, PERCENT + 0.03e18);

        Vars memory _before = _state();
        BorrowOffer memory offerBefore = size.getBorrowOffer(alice);
        uint256 loansBefore = size.activeLoans();

        uint256 loanId = _lendAsMarketOrder(bob, alice, faceValue, dueDate);
        Loan memory loan = size.getLoan(loanId);

        Vars memory _after = _state();
        BorrowOffer memory offerAfter = size.getBorrowOffer(alice);
        uint256 loansAfter = size.activeLoans();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + amountIn);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - amountIn);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount + faceValue);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amountIn);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(loan.faceValue, faceValue);
        assertEq(loan.dueDate, dueDate);
        assertTrue(loan.isFOL());
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_exactAmountIn() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _borrowAsLimitOrder(alice, 100e18, 0.03e18, 12);

        uint256 amountIn = 10e18;
        uint256 dueDate = 12;
        uint256 faceValue = Math.mulDivDown(amountIn, PERCENT + 0.03e18, PERCENT);

        Vars memory _before = _state();
        BorrowOffer memory offerBefore = size.getBorrowOffer(alice);
        uint256 loansBefore = size.activeLoans();

        uint256 loanId = _lendAsMarketOrder(bob, alice, amountIn, dueDate, true);
        Loan memory loan = size.getLoan(loanId);

        Vars memory _after = _state();
        BorrowOffer memory offerAfter = size.getBorrowOffer(alice);
        uint256 loansAfter = size.activeLoans();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + amountIn);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - amountIn);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount + faceValue);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amountIn);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(loan.faceValue, faceValue);
        assertEq(loan.dueDate, dueDate);
        assertTrue(loan.isFOL());
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_exactAmountIn(uint256 amountIn, uint256 seed) public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        _borrowAsLimitOrder(alice, 100e18, curve.timeBuckets, curve.rates);

        amountIn = bound(amountIn, 5e18, 100e18);
        uint256 dueDate = block.timestamp + (curve.timeBuckets[0] + curve.timeBuckets[1]) / 2;
        uint256 r = PERCENT + YieldCurveLibrary.getRate(curve, dueDate);
        uint256 faceValue = Math.mulDivDown(amountIn, r, PERCENT);

        Vars memory _before = _state();
        BorrowOffer memory offerBefore = size.getBorrowOffer(alice);
        uint256 loansBefore = size.activeLoans();

        uint256 loanId = _lendAsMarketOrder(bob, alice, amountIn, dueDate, true);
        Loan memory loan = size.getLoan(loanId);

        Vars memory _after = _state();
        BorrowOffer memory offerAfter = size.getBorrowOffer(alice);
        uint256 loansAfter = size.activeLoans();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + amountIn);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - amountIn);
        assertEq(_after.alice.debtAmount, _before.alice.debtAmount + faceValue);
        assertEq(offerAfter.maxAmount, offerBefore.maxAmount - amountIn);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(loan.faceValue, faceValue);
        assertEq(loan.dueDate, dueDate);
        assertTrue(loan.isFOL());
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _borrowAsLimitOrder(alice, 200e18, 0, 12);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.USER_IS_LIQUIDATABLE.selector, alice, 1.5e18 / 2));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({borrower: alice, dueDate: 12, amount: 200e18, exactAmountIn: false})
        );
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_reverts_if_dueDate_out_of_range() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        _borrowAsLimitOrder(alice, 200e18, curve.timeBuckets, curve.rates);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_OUT_OF_RANGE.selector, 6 days, 30 days, 150 days));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 6 days,
                amount: 10e18,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.DUE_DATE_OUT_OF_RANGE.selector, 151 days, 30 days, 150 days));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 151 days,
                amount: 10e18,
                exactAmountIn: false
            })
        );

        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 150 days,
                amount: 10e18,
                exactAmountIn: false
            })
        );
    }
}
