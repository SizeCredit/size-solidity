// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {LoanStatus} from "@src/libraries/LoanLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";

import {Math} from "@src/libraries/MathLibrary.sol";

contract RepayTest is BaseTest {
    function test_Repay_repay_full_FOL() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - faceValue);
        assertEq(_after.protocolBorrowAmount, _before.protocolBorrowAmount + faceValue);
        assertTrue(size.getLoan(loanId).repaid);
    }

    function test_Repay_repay_partial_FOL() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(bob, loanId, faceValue / 2);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue / 2);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - faceValue / 2);
        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + faceValue / 2);
        assertTrue(!size.getLoan(loanId).repaid);
    }

    function test_Repay_overdue_does_not_increase_debt() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();
        assertEq(size.getLoanStatus(loanId), LoanStatus.ACTIVE);

        vm.warp(365 days);

        Vars memory _overdue = _state();

        assertEq(_overdue.bob.debtAmount, _before.bob.debtAmount);
        assertEq(_overdue.bob.borrowAmount, _before.bob.borrowAmount);
        assertEq(_overdue.protocolBorrowAmount, _before.protocolBorrowAmount);
        assertTrue(!size.getLoan(loanId).repaid);
        assertEq(size.getLoanStatus(loanId), LoanStatus.OVERDUE);

        _repay(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - faceValue);
        assertEq(_after.protocolBorrowAmount, _before.protocolBorrowAmount + faceValue);
        assertTrue(size.getLoan(loanId).repaid);
        assertEq(size.getLoanStatus(loanId), LoanStatus.REPAID);
    }

    function test_Repay_repay_claimed_should_revert() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        _borrowAsMarketOrder(bob, candy, 100e18, 12);

        Vars memory _before = _state();

        _repay(bob, loanId);
        _claim(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e18);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - 200e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId));
        _repay(bob, loanId);
    }

    function test_Repay_repay_full_of_SOL() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(alice, solId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + faceValue);
        // @audit this is not correct
        assertTrue(!size.getLoan(loanId).repaid);
    }

    function test_Repay_repay_partial_of_SOL() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0.05e18, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 10e18, 12, [loanId]);
        uint256 faceValue = Math.mulDivUp(amountLoanId1, PERCENT + 0.05e18, PERCENT);

        Vars memory _before = _state();

        _repay(alice, solId, faceValue / 2);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - faceValue / 2);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + faceValue / 2);
        assertTrue(!size.getLoan(loanId).repaid);
    }
}
