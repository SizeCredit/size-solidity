// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {RepayParams} from "@src/libraries/actions/Repay.sol";
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

        _repay(bob, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - futureValue);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - futureValue);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEq(_after.size.borrowATokenBalance, _before.size.borrowATokenBalance + futureValue);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
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
        assertEq(_overdue.bob.borrowATokenBalance, _before.bob.borrowATokenBalance);
        assertEq(_overdue.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.OVERDUE);

        _repay(bob, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - futureValue);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - futureValue);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEq(_after.size.borrowATokenBalance, _before.size.borrowATokenBalance + futureValue);
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

        _repay(bob, debtPositionId);
        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + futureValue);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - futureValue);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertEq(_after.size.borrowATokenBalance, _before.size.borrowATokenBalance, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        _repay(bob, debtPositionId);
    }

    function test_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowAToken() internal {}

    function testFuzz_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowAToken(
        uint256 borrowATokenBalance,
        uint256 repayAmount
    ) internal {
        borrowATokenBalance = bound(borrowATokenBalance, size.riskConfig().minimumCreditBorrowAToken, 100e6);
        repayAmount = bound(repayAmount, 0, borrowATokenBalance);

        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, borrowATokenBalance, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.prank(bob);
        try size.repay(RepayParams({debtPositionId: debtPositionId})) {} catch {}
        assertGe(size.getCreditPosition(creditPositionId).credit, size.riskConfig().minimumCreditBorrowAToken);
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
        _repay(bob, debtPositionId);
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
        _repay(bob, debtPositionId);

        _deposit(candy, usdc, futureValue2 - amount);
        _repay(candy, loanId2);

        assertEq(size.getUserView(feeRecipient).collateralTokenBalance, 0);
        assertEq(_state().bob.collateralTokenBalance, _state().candy.collateralTokenBalance);
    }

    function test_Repay_repay_after_price_decrease() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 3000e6);
        _deposit(bob, weth, 500e18);
        _sellCreditLimit(bob, [int256(0.03e18), int256(0.03e18)], [uint256(30 days), uint256(60 days)]);
        _buyCreditMarket(alice, bob, 100e6, 40 days);
        _buyCreditMarket(alice, bob, 200e6, 50 days);
        _setPrice(0.0001e18);
        _repay(bob, 0);
    }
}
