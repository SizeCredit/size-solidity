// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {Loan, LoanLibrary} from "@src/libraries/LoanLibrary.sol";

contract CompensateTest is BaseTest {
    using LoanLibrary for Loan;

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

        uint256 repaidLoanDebtBefore = size.getLoan(loanId3).getDebt();
        uint256 compensatedLoanCreditBefore = size.getLoan(loanId).getCredit();

        _compensate(alice, loanId3, loanId);

        uint256 repaidLoanDebtAfter = size.getLoan(loanId3).getDebt();
        uint256 compensatedLoanCreditAfter = size.getLoan(loanId).getCredit();

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 2 * 20e18);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 2 * 20e18);
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore - compensatedLoanCreditAfter);
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

        uint256 repaidLoanDebtBefore = size.getLoan(solId).getDebt();
        uint256 compensatedLoanCreditBefore = size.getLoan(loanId).getCredit();

        _compensate(alice, solId, loanId);

        uint256 repaidLoanDebtAfter = size.getLoan(solId).getDebt();
        uint256 compensatedLoanCreditAfter = size.getLoan(loanId).getCredit();

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 15e18);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 15e18);
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore - compensatedLoanCreditAfter);
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

        uint256 repaidLoanDebtBefore = size.getLoan(solId).getDebt();
        uint256 compensatedLoanCreditBefore = size.getLoan(solId2).getCredit();

        _compensate(alice, solId, solId2);

        uint256 repaidLoanDebtAfter = size.getLoan(solId).getDebt();
        uint256 compensatedLoanCreditAfter = size.getLoan(solId2).getCredit();

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 10e18);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 10e18);
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore - compensatedLoanCreditAfter);
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
        vm.expectRevert();
        _compensate(alice, loanId, loanId2);
    }

    function test_Compensate_compensate_SOL_repaid_FOL_works() public {
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

        assertEq(size.activeLoans(), 4);

        _repay(bob, loanId);

        uint256 repaidLoanDebtBefore = size.getLoan(solId).getDebt();
        uint256 compensatedLoanCreditBefore = size.getLoan(loanId2).getCredit();

        _compensate(alice, solId, loanId2);

        uint256 repaidLoanDebtAfter = size.getLoan(solId).getDebt();
        uint256 compensatedLoanCreditAfter = size.getLoan(loanId2).getCredit();

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 15e18);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 15e18);
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore - compensatedLoanCreditAfter);
    }
}
