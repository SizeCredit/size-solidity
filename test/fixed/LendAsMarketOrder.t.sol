// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {LoanOffer, OfferLibrary} from "@src/libraries/fixed/OfferLibrary.sol";
import {YieldCurve, YieldCurveLibrary} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {LendAsMarketOrderParams} from "@src/libraries/fixed/actions/LendAsMarketOrder.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/libraries/Math.sol";

contract LendAsMarketOrderTest is BaseTest {
    using OfferLibrary for LoanOffer;

    function test_LendAsMarketOrder_lendAsMarketOrder_transfers_to_borrower() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        uint256 rate = 0.03e18;
        _borrowAsLimitOrder(alice, int256(rate), block.timestamp + 365 days);

        uint256 issuanceValue = 10e6;
        uint256 faceValue = Math.mulDivUp(issuanceValue, PERCENT + rate, PERCENT);
        uint256 dueDate = block.timestamp + 365 days;
        uint256 amountIn = Math.mulDivUp(faceValue, PERCENT, PERCENT + rate);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _lendAsMarketOrder(bob, alice, faceValue, dueDate);
        uint256 repayFee = size.repayFee(debtPositionId);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountIn);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + faceValue + repayFee);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getDebt(debtPositionId), faceValue + repayFee);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_exactAmountIn() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _borrowAsLimitOrder(alice, 0.03e18, block.timestamp + 365 days);

        uint256 amountIn = 10e6;
        uint256 dueDate = block.timestamp + 365 days;
        uint256 faceValue = Math.mulDivDown(amountIn, PERCENT + 0.03e18, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _lendAsMarketOrder(bob, alice, amountIn, dueDate, true);
        uint256 repayFee = size.repayFee(debtPositionId);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountIn);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + faceValue + repayFee);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }

    function testFuzz_LendAsMarketOrder_lendAsMarketOrder_exactAmountIn(uint256 amountIn, uint256 seed) public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        marketBorrowRateFeed.setMarketBorrowRate(0);
        YieldCurve memory curve = YieldCurveHelper.getRandomYieldCurve(seed);
        _borrowAsLimitOrder(alice, curve);

        amountIn = bound(amountIn, 5e6, 100e6);
        uint256 dueDate = block.timestamp + (curve.maturities[0] + curve.maturities[1]) / 2;
        uint256 rate = YieldCurveLibrary.getRatePerMaturity(curve, marketBorrowRateFeed, dueDate);
        uint256 faceValue = Math.mulDivDown(amountIn, PERCENT + rate, PERCENT);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId = _lendAsMarketOrder(bob, alice, amountIn, dueDate, true);
        uint256 repayFee = size.repayFee(debtPositionId);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + amountIn);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - amountIn);
        assertEq(_after.alice.debtBalance, _before.alice.debtBalance + faceValue + repayFee);
        assertEq(loansAfter, loansBefore + 1);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, faceValue);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _borrowAsLimitOrder(alice, 0, block.timestamp + 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, alice, 1.5e18 / 2, 1.5e18)
        );
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 365 days,
                amount: 200e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_cannot_surpass_debtTokenCap() public {
        _setPrice(1e18);
        _updateConfig("debtTokenCap", 5e6);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        _borrowAsLimitOrder(alice, 0, block.timestamp + 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.DEBT_TOKEN_CAP_EXCEEDED.selector, size.config().debtTokenCap, 10e6)
        );
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 365 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }

    function test_LendAsMarketOrder_lendAsMarketOrder_reverts_if_dueDate_out_of_range() public {
        _setPrice(1e18);
        _deposit(alice, weth, 150e18);
        _deposit(bob, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.normalCurve();
        _borrowAsLimitOrder(alice, curve);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.MATURITY_OUT_OF_RANGE.selector, 6 days, 30 days, 150 days));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 6 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.MATURITY_OUT_OF_RANGE.selector, 151 days, 30 days, 150 days));
        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 151 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        size.lendAsMarketOrder(
            LendAsMarketOrderParams({
                borrower: alice,
                dueDate: block.timestamp + 150 days,
                amount: 10e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
    }
}
