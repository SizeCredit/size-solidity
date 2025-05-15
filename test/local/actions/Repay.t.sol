// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {LoanStatus, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";
import {RepayParams} from "@src/market/libraries/actions/Repay.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract RepayTest is BaseTest {
    function test_Repay_repay_full_DebtPosition() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.05e18));
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amountLoanId1, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        Vars memory _before = _state();

        _repay(bob, debtPositionId, bob);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - futureValue);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance - futureValue);
        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance);
        assertEq(_after.size.borrowTokenBalance, _before.size.borrowTokenBalance + futureValue);
        assertEq(_after.variablePool.borrowTokenBalance, _before.variablePool.borrowTokenBalance);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
    }

    function test_Repay_overdue_does_not_increase_debt() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.05e18));
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amountLoanId1, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        Vars memory _before = _state();
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        vm.warp(block.timestamp + 365 days + 1);

        Vars memory _overdue = _state();

        assertEq(_overdue.bob.debtBalance, _before.bob.debtBalance);
        assertEq(_overdue.bob.borrowTokenBalance, _before.bob.borrowTokenBalance);
        assertEq(_overdue.variablePool.borrowTokenBalance, _before.variablePool.borrowTokenBalance);
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.OVERDUE);

        _repay(bob, debtPositionId, bob);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - futureValue);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance - futureValue);
        assertEq(_after.variablePool.borrowTokenBalance, _before.variablePool.borrowTokenBalance);
        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance);
        assertEq(_after.size.borrowTokenBalance, _before.size.borrowTokenBalance + futureValue);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
    }

    function test_Repay_repay_claimed_should_revert() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 150e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(bob, candy, RESERVED_ID, 100e6, 365 days, false);

        Vars memory _before = _state();

        _repay(bob, debtPositionId, bob);
        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowTokenBalance, _before.alice.borrowTokenBalance + futureValue);
        assertEq(_after.bob.borrowTokenBalance, _before.bob.borrowTokenBalance - futureValue);
        assertEq(_after.variablePool.borrowTokenBalance, _before.variablePool.borrowTokenBalance);
        assertEq(_after.size.borrowTokenBalance, _before.size.borrowTokenBalance, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        _repay(bob, debtPositionId, bob);
    }

    function test_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowToken() internal {}

    function testFuzz_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowToken(
        uint256 borrowTokenBalance,
        uint256 repayAmount
    ) internal {
        borrowTokenBalance = bound(borrowTokenBalance, size.riskConfig().minimumCreditBorrowToken, 100e6);
        repayAmount = bound(repayAmount, 0, borrowTokenBalance);

        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, borrowTokenBalance, 12 days, false);
        address borrower = bob;
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.prank(bob);
        try size.repay(RepayParams({debtPositionId: debtPositionId, borrower: borrower})) {} catch {}
        assertGe(size.getCreditPosition(creditPositionId).credit, size.riskConfig().minimumCreditBorrowToken);
    }

    function test_Repay_repay_pays_fee_simple() public {
        _setPrice(1e18);
        _deposit(bob, weth, 200e18);
        _deposit(alice, usdc, 150e6);
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0.1e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, curve);
        uint256 amount = 100e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        vm.warp(block.timestamp + 365 days);

        _deposit(bob, usdc, futureValue - amount);
        _repay(bob, debtPositionId, bob);
    }

    function test_Repay_repay_fee_change_fee_after_borrow() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0.05e18);
        _deposit(candy, weth, 200e18);
        _deposit(bob, weth, 200e18);
        _deposit(alice, usdc, 300e6);
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0);
        _buyCreditLimit(alice, block.timestamp + 365 days, curve);
        uint256 amount = 100e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        // admin changes fees
        _updateConfig("swapFeeAPR", 0.1e18);

        uint256 loanId2 = _sellCreditMarket(candy, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue2 = size.getDebtPosition(loanId2).futureValue;

        assertTrue(futureValue != futureValue2);

        vm.warp(block.timestamp + 365 days);

        _deposit(bob, usdc, futureValue - amount);
        _repay(bob, debtPositionId, bob);

        _deposit(candy, usdc, futureValue2 - amount);
        _repay(candy, loanId2, candy);

        assertEq(size.getUserView(feeRecipient).collateralTokenBalance, 0);
        assertEq(_state().bob.collateralTokenBalance, _state().candy.collateralTokenBalance);
    }

    function test_Repay_repay_after_price_decrease() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 3000e6);
        _deposit(bob, weth, 500e18);
        _sellCreditLimit(
            bob, block.timestamp + 365 days, [int256(0.03e18), int256(0.03e18)], [uint256(30 days), uint256(60 days)]
        );
        uint256 debtPositionId = _buyCreditMarket(alice, bob, 100e6, 40 days);
        _buyCreditMarket(alice, bob, 200e6, 50 days);
        _setPrice(0.0001e18);
        _repay(bob, debtPositionId, bob);
    }
}
