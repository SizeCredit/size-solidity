// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {PERCENT} from "@src/libraries/Math.sol";
import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";
import {RepayParams} from "@src/libraries/fixed/actions/Repay.sol";

import {Math} from "@src/libraries/Math.sol";

contract RepayTest is BaseTest {
    function test_Repay_repay_full_FOL() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        uint256 faceValue = Math.mulDivUp(amountFixedLoanId1, PERCENT + 0.05e18, PERCENT);
        uint256 faceValueUSDC = Math.mulDivUp(faceValue, 1e6, 1e6);

        Vars memory _before = _state();

        _repay(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - faceValue);
        // assertEq(_after.bob.vpBorrowAmount, _before.bob.vpBorrowAmount, 0);
        // assertEq(_after.alice.vpBorrowAmount, _before.alice.vpBorrowAmount + faceValueUSDC);
        assertEq(_after.vpBorrowAmount, _before.vpBorrowAmount + faceValue);
        assertTrue(size.getFixedLoan(loanId).repaid);
    }

    function test_Repay_repay_partial_FOL() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        uint256 faceValue = Math.mulDivUp(amountFixedLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(bob, loanId, faceValue / 2);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue / 2);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - faceValue / 2);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + faceValue / 2);
        // assertEq(_after.bob.vpBorrowAmount, _before.bob.vpBorrowAmount, 0);
        // assertEq(_after.alice.vpBorrowAmount, _before.alice.vpBorrowAmount, 0);
        assertTrue(!size.getFixedLoan(loanId).repaid);
    }

    function test_Repay_overdue_does_not_increase_debt() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        uint256 faceValue = Math.mulDivUp(amountFixedLoanId1, PERCENT + 0.05e18, PERCENT);
        uint256 faceValueUSDC = Math.mulDivUp(faceValue, 1e6, 1e6);

        Vars memory _before = _state();
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.ACTIVE);

        vm.warp(365 days);

        Vars memory _overdue = _state();

        assertEq(_overdue.bob.debtAmount, _before.bob.debtAmount);
        assertEq(_overdue.bob.borrowAmount, _before.bob.borrowAmount);
        // assertEq(_overdue.vpBorrowAmount, _before.vpBorrowAmount);
        assertTrue(!size.getFixedLoan(loanId).repaid);
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.OVERDUE);

        _repay(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - faceValue);
        // assertEq(_after.vpBorrowAmount, _before.vpBorrowAmount + faceValue);
        // assertEq(_after.bob.vpBorrowAmount, _before.bob.vpBorrowAmount, 0);
        // assertEq(_after.alice.vpBorrowAmount, _before.alice.vpBorrowAmount + faceValueUSDC);
        assertTrue(size.getFixedLoan(loanId).repaid);
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.REPAID);
    }

    function test_Repay_repay_claimed_should_revert() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _borrowAsMarketOrder(bob, candy, 100e6, 12);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e6);
        // assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 200e6);
        // assertEq(_after.bob.vpBorrowAmount, _before.bob.vpBorrowAmount, 0);
        // assertEq(_after.alice.vpBorrowAmount, _before.alice.vpBorrowAmount, 0);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId));
        _repay(bob, loanId);
    }

    function test_Repay_repay_full_of_SOL() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e6, 12, [loanId]);
        uint256 faceValue = Math.mulDivUp(amountFixedLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(alice, solId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + faceValue);
        // assertEq(_after.bob.vpBorrowAmount, _before.bob.vpBorrowAmount, 0);
        // assertEq(_after.alice.vpBorrowAmount, _before.alice.vpBorrowAmount, 0);
        // @audit this is not correct
        assertTrue(!size.getFixedLoan(loanId).repaid);
    }

    function test_Repay_repay_partial_of_SOL() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 100e6, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e6, 12, 0.05e18, 12);
        uint256 amountFixedLoanId1 = 10e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountFixedLoanId1, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e6, 12, [loanId]);
        uint256 faceValue = Math.mulDivUp(amountFixedLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(alice, solId, faceValue / 2);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue / 2);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + faceValue / 2);
        // assertEq(_after.bob.vpBorrowAmount, _before.bob.vpBorrowAmount, 0);
        // assertEq(_after.alice.vpBorrowAmount, _before.alice.vpBorrowAmount, 0);
        assertTrue(!size.getFixedLoan(loanId).repaid);
    }

    function test_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowAsset() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _lendAsLimitOrder(alice, 100e6, 12, 0, 12);
        uint256 amount = 10e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector, 4e18, size.config().minimumCreditBorrowAsset
            )
        );
        _repay(bob, loanId, 6e18);
        assertGt(size.getCredit(loanId), size.config().minimumCreditBorrowAsset);
    }

    function test_Repay_repay_partial_cannot_leave_loan_below_minimumCreditBorrowAsset(
        uint256 borrowAmount,
        uint256 repayAmount
    ) public {
        borrowAmount = bound(borrowAmount, size.config().minimumCreditBorrowAsset, 100e6);
        repayAmount = bound(repayAmount, 0, borrowAmount);

        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _lendAsLimitOrder(alice, 100e6, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, borrowAmount, 12);

        vm.prank(bob);
        try size.repay(RepayParams({loanId: loanId, amount: repayAmount})) {} catch {}
        assertGe(size.getCredit(loanId), size.config().minimumCreditBorrowAsset);
    }
}
