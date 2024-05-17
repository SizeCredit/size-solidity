// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Math} from "@src/libraries/Math.sol";

contract RepayTest is BaseTest {
    function test_Repay_repay_full_DebtPosition() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.05e18);
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amountLoanId1, block.timestamp + 365 days);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(bob, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - faceValue);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - faceValue);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEq(_after.size.borrowATokenBalance, _before.size.borrowATokenBalance + faceValue);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 0);
    }

    function test_Repay_overdue_does_not_increase_debt() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.05e18);
        uint256 amountLoanId1 = 10e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amountLoanId1, block.timestamp + 365 days);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        vm.warp(block.timestamp + 365 days + 1);

        Vars memory _overdue = _state();

        assertEq(_overdue.bob.debtBalance, _before.bob.debtBalance);
        assertEq(_overdue.bob.borrowATokenBalance, _before.bob.borrowATokenBalance);
        assertEq(_overdue.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertGt(size.getDebtPosition(debtPositionId).faceValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.OVERDUE);

        _repay(bob, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - faceValue);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - faceValue);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance);
        assertEq(_after.size.borrowATokenBalance, _before.size.borrowATokenBalance + faceValue);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
    }

    function test_Repay_repay_claimed_should_revert() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(bob, candy, 100e6, block.timestamp + 365 days);

        Vars memory _before = _state();

        _repay(bob, debtPositionId);
        _claim(bob, creditId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6);
        assertEq(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - 200e6);
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
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, borrowATokenBalance, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.prank(bob);
        try size.repay(RepayParams({debtPositionId: debtPositionId})) {} catch {}
        assertGe(size.getCreditPosition(creditPositionId).credit, size.riskConfig().minimumCreditBorrowAToken);
    }

    function test_Repay_repay_pays_fee_simple() public {
        _setPrice(1e18);
        _deposit(bob, weth, 200e18);
        _deposit(alice, usdc, 100e6);
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0.1e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);

        vm.warp(block.timestamp + 365 days);

        _deposit(bob, usdc, 10e6 + 0.5e6);
        _repay(bob, debtPositionId);
    }

    function test_Repay_repay_fee_change_fee_after_borrow() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0.05e18);
        _deposit(candy, weth, 180e18);
        _deposit(bob, weth, 180e18);
        _deposit(alice, usdc, 200e6);
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);

        // admin changes fees
        _updateConfig("swapFeeAPR", 0.1e18);

        uint256 loanId2 = _borrowAsMarketOrder(candy, alice, 100e6, block.timestamp + 365 days);

        vm.warp(block.timestamp + 365 days);

        _deposit(bob, usdc, 100e6 + 0.5e6);
        _repay(bob, debtPositionId);

        _deposit(candy, usdc, 100e6 + 0.1e6);
        _repay(candy, loanId2);

        assertEq(size.getUserView(feeRecipient).collateralTokenBalance, 0);
        assertEq(_state().bob.collateralTokenBalance, _state().candy.collateralTokenBalance, 180e18);
    }
}
