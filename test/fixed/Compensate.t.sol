// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract CompensateTest is BaseTest {
    function test_Compensate_compensate_reduces_repaid_loan_debt_and_compensated_loan_credit() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        _lendAsLimitOrder(bob, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 12, 1e18, 12);
        _lendAsLimitOrder(james, 12, 1e18, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 20e6, 12);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId3 = _borrowAsMarketOrder(alice, james, 20e6, 12);
        uint256 repayFee = size.repayFee(debtPositionId);

        uint256 repaidLoanDebtBefore = size.getDebt(loanId3);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, loanId3, creditPositionId);

        uint256 repaidLoanDebtAfter = size.getDebt(loanId3);
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId).credit;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 2 * 20e6 - repayFee);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 2 * 20e6);
        assertEq(
            repaidLoanDebtBefore - repaidLoanDebtAfter - repayFee,
            compensatedLoanCreditBefore - compensatedLoanCreditAfter
        );
    }

    function test_Compensate_compensate_DebtPosition_with_CreditPosition_reduces_DebtPosition_debt_and_CreditPosition_credit(
    ) public {
        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 200e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 200e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(bob, 12, 0, 12);
        _lendAsLimitOrder(candy, 12, 0, 12);
        _lendAsLimitOrder(james, 12, 0, 12);
        _borrowAsMarketOrder(bob, alice, 40e6, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 20e6, 12);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(bob, alice, 10e6, 12, [creditPositionId]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        uint256 repaidLoanDebtBefore = size.getDebt(debtPositionId);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId2).credit;

        _compensate(alice, debtPositionId, creditPositionId2);

        uint256 repaidLoanDebtAfter = size.getDebt(debtPositionId);
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId2).credit;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 10e6);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 10e6);
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore - compensatedLoanCreditAfter);
    }

    function test_Compensate_compensate_DebtPosition_repaid_reverts() public {
        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 200e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 200e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(bob, 12, 0, 12);
        _lendAsLimitOrder(candy, 12, 0, 12);
        _lendAsLimitOrder(james, 12, 0, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 40e6, 12);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, 20e6, 12);

        _repay(alice, loanId2);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, loanId2));
        _compensate(alice, loanId2, creditPositionId);
    }

    function test_Compensate_compensate_full_claim() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, weth, 150e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(bob, 12, 0, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _borrowAsMarketOrder(candy, bob, 100e6, 12);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        _compensate(bob, debtPositionId, creditPositionId2);
        _setLiquidityIndex(2e27);

        Vars memory _before = _state();

        _claim(alice, creditPositionId);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowAmount, _before.alice.borrowAmount + 200e6, 200e6);
    }
}
