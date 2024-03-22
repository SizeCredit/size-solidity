// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";

import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
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
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 20e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId3 = _borrowAsMarketOrder(alice, james, 20e6, block.timestamp + 365 days);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(loanId3)[0];
        uint256 repayFee = size.getDebtPosition(debtPositionId).repayFee;

        uint256 repaidLoanDebtBefore = size.getDebt(loanId3);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, creditPositionId3, creditPositionId);

        uint256 repaidLoanDebtAfter = size.getDebt(loanId3);
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId).credit;

        assertEq(
            repaidLoanDebtAfter, repaidLoanDebtBefore - 2 * 20e6 - repayFee - size.feeConfig().overdueLiquidatorReward
        );
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 2 * 20e6);
        assertEq(
            repaidLoanDebtBefore - repaidLoanDebtAfter - repayFee - size.feeConfig().overdueLiquidatorReward,
            compensatedLoanCreditBefore - compensatedLoanCreditAfter
        );
    }

    function test_Compensate_compensate_CreditPosition_with_CreditPosition_reduces_DebtPosition_debt_and_CreditPosition_credit(
    ) public {
        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 200e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 200e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0);
        _borrowAsMarketOrder(bob, alice, 40e6, block.timestamp + 365 days);
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 20e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 repayFee = size.getDebtPosition(debtPositionId).repayFee;
        uint256 prorataRepayFee = repayFee / 2;
        _borrowAsMarketOrder(bob, alice, 10e6, block.timestamp + 365 days, [creditPositionId]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        uint256 repaidLoanDebtBefore = size.getDebt(debtPositionId);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId2).credit;
        uint256 creditFromRepaidPositionBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, creditPositionId, creditPositionId2);

        uint256 repaidLoanDebtAfter = size.getDebt(debtPositionId);
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId2).credit;
        uint256 creditFromRepaidPositionAfter = size.getCreditPosition(creditPositionId).credit;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 10e6 - prorataRepayFee);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 10e6);
        assertEq(
            repaidLoanDebtBefore - repaidLoanDebtAfter - prorataRepayFee,
            compensatedLoanCreditBefore - compensatedLoanCreditAfter
        );
        assertEq(creditFromRepaidPositionAfter, creditFromRepaidPositionBefore - 10e6);
    }

    function testFuzz_Compensate_compensate_catch_rounding_issue(uint256 borrowAmount, int256 rate) public {
        uint256 amount = 200e6;

        rate = bound(rate, 0, 1e18);
        borrowAmount = bound(borrowAmount, size.riskConfig().minimumCreditBorrowAToken, amount);

        _deposit(alice, weth, 2e18);
        _deposit(alice, usdc, amount);
        _deposit(bob, weth, 2e18);
        _deposit(bob, usdc, amount);
        _deposit(candy, weth, 2e18);
        _deposit(candy, usdc, amount);
        _deposit(james, weth, 2e18);
        _deposit(james, usdc, amount);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, rate);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, rate);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, rate);
        _lendAsLimitOrder(james, block.timestamp + 365 days, rate);

        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        uint256[] memory receivableCreditPositionIds = new uint256[](1);
        receivableCreditPositionIds[0] = creditPositionId;

        vm.prank(bob);
        try size.borrowAsMarketOrder(
            BorrowAsMarketOrderParams({
                lender: alice,
                amount: borrowAmount,
                dueDate: block.timestamp + 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false,
                receivableCreditPositionIds: receivableCreditPositionIds
            })
        ) {
            uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

            vm.prank(alice);
            (bool success, bytes memory err) = address(size).call(
                abi.encodeCall(
                    Size.compensate,
                    CompensateParams({
                        creditPositionWithDebtToRepayId: creditPositionId,
                        creditPositionToCompensateId: creditPositionId2,
                        amount: type(uint256).max
                    })
                )
            );
            if (!success) {
                assertIn(
                    bytes4(err),
                    [
                        Errors.CREDIT_LOWER_THAN_AMOUNT_TO_COMPENSATE.selector,
                        Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT.selector,
                        Errors.CREDIT_LOWER_THAN_MINIMUM_CREDIT_OPENING.selector
                    ]
                );
            }
        } catch {}
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
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 40e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _borrowAsMarketOrder(alice, candy, 20e6, block.timestamp + 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];

        _repay(alice, loanId2);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_ALREADY_REPAID.selector, creditPositionId2));
        _compensate(alice, creditPositionId2, creditPositionId);
    }

    function test_Compensate_compensate_full_claim() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, weth, 150e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 12 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _borrowAsMarketOrder(candy, bob, 100e6, block.timestamp + 12 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        _compensate(bob, creditPositionId, creditPositionId2);
        uint256 creditPosition2_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[1];

        Vars memory _before = _state();

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionId));
        _claim(alice, creditPositionId);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, creditPosition2_2));
        _claim(alice, creditPosition2_2);

        _repay(candy, debtPositionId2);
        _setLiquidityIndex(2e27);
        _claim(alice, creditPosition2_2);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6, 200e6);
    }

    function test_Compensate_compensate_compensated_loan_can_be_liquidated() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(1e18)], [uint256(365 days)]);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, [int256(1e18)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(1e18)], [uint256(365 days)]);
        uint256 loanToCompensateId = _borrowAsMarketOrder(bob, alice, 20e6, block.timestamp + 365 days);
        uint256 creditPositionToCompensateId = size.getCreditPositionIdsByDebtPositionId(loanToCompensateId)[0];
        uint256 loanToRepay = _borrowAsMarketOrder(alice, james, 20e6, block.timestamp + 365 days);
        uint256 creditPositionWithDebtToRepayId = size.getCreditPositionIdsByDebtPositionId(loanToRepay)[0];
        uint256 repayFee = size.getDebtPosition(loanToCompensateId).repayFee;

        uint256 repaidLoanDebtBefore = size.getDebt(loanToRepay);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionToCompensateId).credit;

        _compensate(alice, creditPositionWithDebtToRepayId, creditPositionToCompensateId);

        uint256 repaidLoanDebtAfter = size.getDebt(loanToRepay);
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionToCompensateId).credit;

        assertEq(
            repaidLoanDebtAfter, repaidLoanDebtBefore - 2 * 20e6 - repayFee - size.feeConfig().overdueLiquidatorReward
        );
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 2 * 20e6);
        assertEq(
            repaidLoanDebtBefore - repaidLoanDebtAfter - repayFee - size.feeConfig().overdueLiquidatorReward,
            compensatedLoanCreditBefore - compensatedLoanCreditAfter
        );
        assertEq(repaidLoanDebtAfter, 0);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionWithDebtToRepayId)
        );
        _claim(james, creditPositionWithDebtToRepayId);

        _setPrice(0.1e18);
        assertTrue(size.isUserUnderwater(bob));
        assertTrue(size.isDebtPositionLiquidatable(loanToCompensateId));

        uint256 newCreditPositionId = size.getCreditPositionIdsByDebtPositionId(loanToCompensateId)[1];

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, newCreditPositionId));
        _claim(james, newCreditPositionId);

        _repay(bob, loanToCompensateId);
        _claim(james, newCreditPositionId);
    }
}
