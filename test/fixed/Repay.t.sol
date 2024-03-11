// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";

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
        uint256 repayFee = size.repayFee(debtPositionId);

        Vars memory _before = _state();

        _repay(bob, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalanceFixed, _before.bob.debtBalanceFixed - faceValue - repayFee);
        assertEq(_after.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed - faceValue);
        assertEq(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed);
        assertEq(_after.size.borrowATokenBalanceFixed, _before.size.borrowATokenBalanceFixed + faceValue);
        assertEq(_after.variablePool.borrowATokenBalanceFixed, _before.variablePool.borrowATokenBalanceFixed);
        assertEq(size.getDebt(debtPositionId), 0);
    }

    function test_Repay_repay_partial_DebtPosition() internal {}

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
        uint256 repayFee = size.repayFee(debtPositionId);

        Vars memory _before = _state();
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        vm.warp(block.timestamp + 365 days);

        Vars memory _overdue = _state();

        assertEq(_overdue.bob.debtBalanceFixed, _before.bob.debtBalanceFixed);
        assertEq(_overdue.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed);
        assertEq(_overdue.variablePool.borrowATokenBalanceFixed, _before.variablePool.borrowATokenBalanceFixed);
        assertGt(size.getDebt(debtPositionId), 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.OVERDUE);

        _repay(bob, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalanceFixed, _before.bob.debtBalanceFixed - faceValue - repayFee);
        assertEq(_after.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed - faceValue);
        assertEq(_after.variablePool.borrowATokenBalanceFixed, _before.variablePool.borrowATokenBalanceFixed);
        assertEq(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed);
        assertEq(_after.size.borrowATokenBalanceFixed, _before.size.borrowATokenBalanceFixed + faceValue);
        assertEq(size.getDebt(debtPositionId), 0);
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

        assertEq(_after.alice.borrowATokenBalanceFixed, _before.alice.borrowATokenBalanceFixed + 200e6);
        assertEq(_after.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed - 200e6);
        assertEq(_after.variablePool.borrowATokenBalanceFixed, _before.variablePool.borrowATokenBalanceFixed);
        assertEq(_after.size.borrowATokenBalanceFixed, _before.size.borrowATokenBalanceFixed, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, debtPositionId));
        _repay(bob, debtPositionId);
    }

    function test_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowAToken() internal {}

    function testFuzz_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowAToken(
        uint256 borrowATokenBalance,
        uint256 repayAmount
    ) internal {
        borrowATokenBalance = bound(borrowATokenBalance, size.config().minimumCreditBorrowAToken, 100e6);
        repayAmount = bound(repayAmount, 0, borrowATokenBalance);

        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, borrowATokenBalance, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.prank(bob);
        try size.repay(RepayParams({debtPositionId: debtPositionId})) {} catch {}
        assertGe(size.getCreditPosition(creditPositionId).credit, size.config().minimumCreditBorrowAToken);
    }

    function test_Repay_repay_pays_repayFeeAPR() private {}

    function test_Repay_repay_pays_repayFeeAPR_at_different_times_different_amounts() private {}
}
