// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {FixedLoan, FixedLoanLibrary} from "@src/libraries/fixed/FixedLoanLibrary.sol";

contract CompensateTest is BaseTest {
    using FixedLoanLibrary for FixedLoan;

    function test_Compensate_compensate_reduces_repaid_loan_debt_and_compensated_loan_credit() public {
        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(candy, 100e18, 100e18);
        _deposit(james, 100e18, 100e18);
        _lendAsLimitOrder(alice, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 1e18, 12);
        _lendAsLimitOrder(james, 100e18, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 20e18, 12);
        uint256 loanId3 = _borrowAsMarketOrder(alice, james, 20e18, 12);

        uint256 repaidFixedLoanDebtBefore = size.getFixedLoan(loanId3).getDebt();
        uint256 compensatedFixedLoanCreditBefore = size.getFixedLoan(loanId).getCredit();

        _compensate(alice, loanId3, loanId);

        uint256 repaidFixedLoanDebtAfter = size.getFixedLoan(loanId3).getDebt();
        uint256 compensatedFixedLoanCreditAfter = size.getFixedLoan(loanId).getCredit();

        assertEq(repaidFixedLoanDebtAfter, repaidFixedLoanDebtBefore - 2 * 20e18);
        assertEq(compensatedFixedLoanCreditAfter, compensatedFixedLoanCreditBefore - 2 * 20e18);
        assertEq(
            repaidFixedLoanDebtBefore - repaidFixedLoanDebtAfter,
            compensatedFixedLoanCreditBefore - compensatedFixedLoanCreditAfter
        );
    }

    function test_Compensate_compensate_SOL_reduces_SOL_debt_and_FOL_loan_credit() public {
        _deposit(alice, 200e18, 200e18);
        _deposit(bob, 200e18, 200e18);
        _deposit(candy, 200e18, 200e18);
        _deposit(james, 200e18, 200e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 40e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 15e18, 12, [loanId]);

        uint256 repaidFixedLoanDebtBefore = size.getFixedLoan(solId).getDebt();
        uint256 compensatedFixedLoanCreditBefore = size.getFixedLoan(loanId).getCredit();

        _compensate(alice, solId, loanId);

        uint256 repaidFixedLoanDebtAfter = size.getFixedLoan(solId).getDebt();
        uint256 compensatedFixedLoanCreditAfter = size.getFixedLoan(loanId).getCredit();

        assertEq(repaidFixedLoanDebtAfter, repaidFixedLoanDebtBefore - 15e18);
        assertEq(compensatedFixedLoanCreditAfter, compensatedFixedLoanCreditBefore - 15e18);
        assertEq(
            repaidFixedLoanDebtBefore - repaidFixedLoanDebtAfter,
            compensatedFixedLoanCreditBefore - compensatedFixedLoanCreditAfter
        );
    }

    function test_Compensate_compensate_SOL_reduces_SOL_debt_and_SOL_loan_credit() public {
        _deposit(alice, 200e18, 200e18);
        _deposit(bob, 200e18, 200e18);
        _deposit(candy, 200e18, 200e18);
        _deposit(james, 200e18, 200e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 40e18, 12);
        uint256 loanId2 = _borrowAsMarketOrder(candy, bob, 20e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 15e18, 12, [loanId]);
        uint256 solId2 = _borrowAsMarketOrder(bob, alice, 10e18, 12, [loanId2]);

        uint256 repaidFixedLoanDebtBefore = size.getFixedLoan(solId).getDebt();
        uint256 compensatedFixedLoanCreditBefore = size.getFixedLoan(solId2).getCredit();

        _compensate(alice, solId, solId2);

        uint256 repaidFixedLoanDebtAfter = size.getFixedLoan(solId).getDebt();
        uint256 compensatedFixedLoanCreditAfter = size.getFixedLoan(solId2).getCredit();

        assertEq(repaidFixedLoanDebtAfter, repaidFixedLoanDebtBefore - 10e18);
        assertEq(compensatedFixedLoanCreditAfter, compensatedFixedLoanCreditBefore - 10e18);
        assertEq(
            repaidFixedLoanDebtBefore - repaidFixedLoanDebtAfter,
            compensatedFixedLoanCreditBefore - compensatedFixedLoanCreditAfter
        );
    }

    function test_Compensate_compensate_FOL_repaid_FOL_reverts() public {
        _deposit(alice, 200e18, 200e18);
        _deposit(bob, 200e18, 200e18);
        _deposit(candy, 200e18, 200e18);
        _deposit(james, 200e18, 200e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 40e18, 12);
        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, 20e18, 12);

        _repay(alice, loanId2);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId2));
        _compensate(alice, loanId2, loanId);
    }

    function test_Compensate_compensate_SOL_repaid_FOL_reverts() public {
        _deposit(alice, 200e18, 200e18);
        _deposit(bob, 200e18, 200e18);
        _deposit(candy, 200e18, 200e18);
        _deposit(james, 200e18, 200e18);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 40e18, 12);
        uint256 loanId2 = _borrowAsMarketOrder(candy, alice, 20e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 15e18, 12, [loanId]);
        _borrowAsMarketOrder(bob, james, 40e18, 12);

        assertEq(size.activeFixedLoans(), 4);

        _repay(bob, loanId);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, solId));
        _compensate(alice, solId, loanId2);
    }
}
