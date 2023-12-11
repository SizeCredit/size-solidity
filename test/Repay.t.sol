// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";
import {YieldCurveLibrary} from "@src/libraries/YieldCurveLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {LoanOffer} from "@src/libraries/OfferLibrary.sol";
import {Loan, LoanStatus} from "@src/libraries/LoanLibrary.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

contract RepayTest is BaseTest {
    function test_Repay_repay_reduces_debt() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e4, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 FV = FixedPointMathLib.mulDivUp(PERCENT + 0.05e4, amountLoanId1, PERCENT);

        Vars memory _before = _state();

        _repay(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - FV);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - FV);
        assertEq(_after.protocolBorrowAmount, _before.protocolBorrowAmount + FV);
        assertTrue(size.getLoan(loanId).repaid);
    }

    function test_Repay_overdue_does_not_increase_debt() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0.05e4, 12);
        uint256 amountLoanId1 = 10e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amountLoanId1, 12);
        uint256 FV = FixedPointMathLib.mulDivUp(PERCENT + 0.05e4, amountLoanId1, PERCENT);

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

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - FV);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - FV);
        assertEq(_after.protocolBorrowAmount, _before.protocolBorrowAmount + FV);
        assertTrue(size.getLoan(loanId).repaid);
        assertEq(size.getLoanStatus(loanId), LoanStatus.REPAID);
    }
}
