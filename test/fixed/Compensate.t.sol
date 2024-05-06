// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Size} from "@src/Size.sol";

import {YieldCurve} from "@src/libraries/fixed/YieldCurveLibrary.sol";

import {BorrowAsMarketOrderParams} from "@src/libraries/fixed/actions/BorrowAsMarketOrder.sol";
import {CompensateParams} from "@src/libraries/fixed/actions/Compensate.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";

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

        uint256 repaidLoanDebtBefore = size.getOverdueDebt(loanId3);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, creditPositionId3, creditPositionId);

        uint256 repaidLoanDebtAfter = size.getOverdueDebt(loanId3);
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

        uint256 repaidLoanDebtBefore = size.getOverdueDebt(debtPositionId);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId2).credit;
        uint256 creditFromRepaidPositionBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, creditPositionId, creditPositionId2);

        uint256 repaidLoanDebtAfter = size.getOverdueDebt(debtPositionId);
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
                        Errors.NULL_AMOUNT.selector,
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

        uint256 repaidLoanDebtBefore = size.getOverdueDebt(loanToRepay);
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionToCompensateId).credit;

        _compensate(alice, creditPositionWithDebtToRepayId, creditPositionToCompensateId);

        uint256 repaidLoanDebtAfter = size.getOverdueDebt(loanToRepay);
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

    function test_Compensate_compensate_experiment() public {
        _setPrice(1e18);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalance, 100e6, "Bob's borrow amount should be 100e6");

        // Bob lends as limit order
        _lendAsLimitOrder(bob, block.timestamp + 10 days, 0.03e18);

        // Candy deposits in USDC
        _deposit(candy, usdc, 100e6);
        assertEq(_state().candy.borrowATokenBalance, 100e6, "Candy's borrow amount should be 100e6");

        // Candy lends as limit order
        _lendAsLimitOrder(candy, block.timestamp + 10 days, 0.05e18);

        // Alice deposits in WETH
        _deposit(alice, weth, 5000e18);
        uint256 dueDate = block.timestamp + 10 days;

        // Alice borrows as market order from Bob
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 50e6, dueDate);
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1, "There should be one active loan");
        assertEq(creditPositionsCount, 1, "There should be one active loan");
        assertTrue(size.isDebtPositionId(debtPositionId), "The first loan should be DebtPosition");

        DebtPosition memory loan = size.getDebtPosition(debtPositionId);

        // Calculate amount to borrow
        uint256 amountToBorrow = loan.faceValue / 10;

        // Bob deposits in WETH
        _deposit(bob, weth, 5000e18);

        // Bob borrows as market order from Candy
        uint256 bobDebtBefore = _state().bob.debtBalance;
        uint256 loanId2 = _borrowAsMarketOrder(bob, candy, amountToBorrow, dueDate);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        uint256 bobDebtAfter = _state().bob.debtBalance;
        assertGt(bobDebtAfter, bobDebtBefore, "Bob's debt should increase");

        // Bob compensates
        uint256 creditPositionToCompensateId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _compensate(bob, creditPositionId2, creditPositionToCompensateId, type(uint256).max);

        assertEq(
            _state().bob.debtBalance,
            bobDebtBefore,
            "Bob's total debt covered by real collateral should revert to previous state"
        );
    }

    function test_Compensate_compensate_pays_repayFeeAPR_pro_rata() public {
        // OK so let's make an example of the approach here
        _setPrice(1e18);
        _updateConfig("collateralTokenCap", type(uint256).max);
        address[] memory users = new address[](4);
        users[0] = alice;
        users[1] = bob;
        users[2] = candy;
        users[3] = james;
        for (uint256 i = 0; i < 4; i++) {
            _deposit(users[i], weth, 500e18);
            _deposit(users[i], usdc, 500e6);
        }
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0.1e18);
        YieldCurve memory curve2 = YieldCurveHelper.pointCurve(365 days, 0);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, curve);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, curve2);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, curve2);
        _lendAsLimitOrder(james, block.timestamp + 365 days, curve2);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPosition1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _borrowAsMarketOrder(candy, james, 200e6, block.timestamp + 365 days);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        _borrowAsMarketOrder(james, bob, 120e6, block.timestamp + 365 days, [creditId2]);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(loanId2)[1];
        // DebtPosition1
        // DebtPosition.Borrower = B1
        // DebtPosition.IV = 100
        // DebtPosition.FullLenderRate = 10%
        // DebtPosition.startTime = 1 Jan 2023
        // DebtPosition.dueDate = 31 Dec 2023 (months)
        // DebtPosition.lastRepaymentTime=0

        // Computable
        // DebtPosition.FV() = DebtPosition.IV * DebtPosition.FullLenderRate
        // Also tracked
        // fol.credit = DebtPosition.FV() --> 110
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 110e6);
        assertEq(size.getDebtPosition(debtPositionId).issuanceValue, 100e6);
        assertEq(size.getCreditPositionsByDebtPositionId(debtPositionId)[0].credit, 110e6);
        assertEq(size.getDebtPosition(debtPositionId).repayFee, 0.5e6);

        // At t=7 borrower compensates for an amount A=20
        // Let's say this amount comes from a CreditPosition CreditPosition1 the borrower owns, so something like
        // CreditPosition1
        // CreditPosition.lender = B1
        // CreditPosition1.credit = 120
        // CreditPosition1.DebtPosition().DueDate = 30 Dec 2023
        assertEq(size.getCreditPosition(creditPositionId).credit, 120e6);

        _compensate(bob, creditPosition1, creditPositionId, 20e6);

        // then the update is
        // CreditPosition1.credit -= 20 --> 100
        assertEq(size.getCreditPosition(creditPositionId).credit, 100e6);

        // Now Borrower has A=20 to compensate his debt on DebtPosition1 which results in
        // DebtPosition1.protocolFees(t=7) = 100 * 0.005  --> 0.29
        assertEq(
            size.getDebtPosition(debtPositionId).issuanceValue, 100e6 - uint256(20e6 * 1e18) / 1.1e18 - 1, 81.818181e6
        );
        assertEq(
            size.getDebtPosition(debtPositionId).repayFee,
            ((100e6 - uint256(20e6 * 1e18) / 1.1e18) * 0.005e18 / 1e18) + 1,
            0.409091e6
        );

        // At this point, we need to take 0.29 USDC in fees and we have 2 ways to do it

        // 2) Taking from collateral
        // In this case, we do the same as the above with
        // NetA = A

        // and no CreditPosition_For_Repayment is emitted
        // and to take the fees instead, we do
        // collateral[borrower] -= DebtPosition1.protocolFees(t=7) / Oracle.CurrentPrice
        assertEq(_state().bob.collateralTokenBalance, 500e18 - (0.5e6 - 0.409091e6) * 1e12);
    }

    function test_Compensate_compensate_with_chain_of_exits() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, usdc, 100e6);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0);

        _deposit(bob, weth, 150e18);

        uint256 debtPositionId_bob = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId_alice = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[0];

        _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 365 days, [creditPositionId_alice]);
        uint256 creditPositionId_bob = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[1];

        _borrowAsMarketOrder(bob, candy, 70e6, block.timestamp + 365 days, [creditPositionId_bob]);
        uint256 creditPositionId_candy = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[2];

        assertEq(size.getDebtPosition(debtPositionId_bob).faceValue, 100e6);
        assertEq(size.getCreditPosition(creditPositionId_alice).credit, 0);
        assertEq(size.getCreditPosition(creditPositionId_bob).credit, 30e6);
        assertEq(size.getCreditPosition(creditPositionId_candy).credit, 70e6);

        _compensate(bob, creditPositionId_candy, creditPositionId_bob);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[3];

        assertEq(size.getDebtPosition(debtPositionId_bob).faceValue, 70e6);
        assertEq(size.getCreditPosition(creditPositionId_alice).credit, 0);
        assertEq(size.getCreditPosition(creditPositionId_bob).credit, 0);
        assertEq(size.getCreditPosition(creditPositionId_candy).credit, 40e6);

        assertEq(size.getCreditPosition(creditPositionId).credit, 30e6);
        assertEq(size.getCreditPosition(creditPositionId).lender, candy);
    }
}
