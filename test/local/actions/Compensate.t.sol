// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Size} from "@src/market/Size.sol";

import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";

import {CREDIT_POSITION_ID_START, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {SellCreditMarketParams} from "@src/market/libraries/actions/SellCreditMarket.sol";
import {
    SetUserConfiguration, SetUserConfigurationParams
} from "@src/market/libraries/actions/SetUserConfiguration.sol";

import {Math} from "@src/market/libraries/Math.sol";
import {BuyCreditMarketParams} from "@src/market/libraries/actions/BuyCreditMarket.sol";
import {CompensateParams} from "@src/market/libraries/actions/Compensate.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {CreditPosition, DebtPosition, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";
import {SellCreditLimitParams} from "@src/market/libraries/actions/SellCreditLimit.sol";

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
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _sellCreditMarket(alice, james, RESERVED_ID, 20e6, 365 days, false);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        uint256 repaidLoanDebtBefore = size.getDebtPosition(debtPositionId2).futureValue;
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, creditPositionId3, creditPositionId);

        uint256 repaidLoanDebtAfter = size.getDebtPosition(debtPositionId2).futureValue;
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId).credit;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - futureValue);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore);
    }

    function test_Compensate_compensate_CreditPosition_with_CreditPosition_reduces_DebtPosition_debt_and_CreditPosition_credit(
    ) public {
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 200e6);
        _deposit(bob, weth, 200e18);
        _deposit(bob, usdc, 200e6);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 200e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 200e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _sellCreditMarket(bob, alice, RESERVED_ID, 70e6, 365 days, false);
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 40e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(bob, alice, creditPositionId, 30e6, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];

        uint256 repaidLoanDebtBefore = size.getDebtPosition(debtPositionId).futureValue;
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionId2).credit;
        uint256 creditFromRepaidPositionBefore = size.getCreditPosition(creditPositionId).credit;

        _compensate(alice, creditPositionId, creditPositionId2);

        uint256 repaidLoanDebtAfter = size.getDebtPosition(debtPositionId).futureValue;
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionId2).credit;
        uint256 creditFromRepaidPositionAfter = size.getCreditPosition(creditPositionId).credit;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 10e6, "x");
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore - 10e6, "y");
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore - compensatedLoanCreditAfter);
        assertEq(creditFromRepaidPositionAfter, creditFromRepaidPositionBefore - 10e6, "z");
    }

    function testFuzz_Compensate_compensate_catch_rounding_issue(uint256 borrowAmount, int256 rate) public {
        uint256 amount = 200e6;

        rate = bound(rate, 0, 1e18);
        borrowAmount = bound(borrowAmount, size.riskConfig().minimumCreditBorrowAToken, amount);
        uint256 exitAmount = borrowAmount / 2;

        _deposit(alice, weth, 2e18);
        _deposit(alice, usdc, 2 * amount);
        _deposit(bob, weth, 2e18);
        _deposit(bob, usdc, 2 * amount);
        _deposit(candy, weth, 2e18);
        _deposit(candy, usdc, 2 * amount);
        _deposit(james, weth, 2e18);
        _deposit(james, usdc, 2 * amount);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, rate));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, rate));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, rate));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, rate));

        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, borrowAmount, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.prank(bob);
        try size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: creditPositionId,
                amount: exitAmount,
                tenor: 365 days,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false
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
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(bob, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(james, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 40e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _sellCreditMarket(alice, candy, RESERVED_ID, 20e6, 12 days, false);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        _repay(alice, debtPositionId2, alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, creditPositionId2));
        _compensate(alice, creditPositionId2, creditPositionId);
    }

    function test_Compensate_compensate_full_claim() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, weth, 150e18);
        _deposit(liquidator, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(bob, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _sellCreditMarket(candy, bob, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        _compensate(bob, creditPositionId, creditPositionId2);
        uint256 creditPosition2_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        Vars memory _before = _state();

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionId));
        _claim(alice, creditPositionId);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, creditPosition2_2));
        _claim(alice, creditPosition2_2);

        _repay(candy, debtPositionId2, candy);
        _setLiquidityIndex(2e27);
        _claim(alice, creditPosition2_2);

        Vars memory _after = _state();

        assertEq(_after.alice.borrowATokenBalance, _before.alice.borrowATokenBalance + 200e6, 200e6);
    }

    function test_Compensate_compensate_compensated_loan_can_be_liquidated() public {
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(1e18)], [uint256(365 days)]);
        _buyCreditLimit(bob, block.timestamp + 365 days, [int256(1e18)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(1e18)], [uint256(365 days)]);
        uint256 loanToCompensateId = _sellCreditMarket(bob, alice, RESERVED_ID, 20e6, 365 days, false);
        uint256 creditPositionToCompensateId = size.getCreditPositionIdsByDebtPositionId(loanToCompensateId)[0];
        uint256 loanToRepay = _sellCreditMarket(alice, james, RESERVED_ID, 20e6, 365 days, false);
        uint256 creditPositionWithDebtToRepayId = size.getCreditPositionIdsByDebtPositionId(loanToRepay)[0];

        uint256 repaidLoanDebtBefore = size.getDebtPosition(loanToRepay).futureValue;
        uint256 compensatedLoanCreditBefore = size.getCreditPosition(creditPositionToCompensateId).credit;
        address lenderBefore = size.getCreditPosition(creditPositionToCompensateId).lender;

        _compensate(alice, creditPositionWithDebtToRepayId, creditPositionToCompensateId);

        uint256 repaidLoanDebtAfter = size.getDebtPosition(loanToRepay).futureValue;
        uint256 compensatedLoanCreditAfter = size.getCreditPosition(creditPositionToCompensateId).credit;
        address lenderAfter = size.getCreditPosition(creditPositionToCompensateId).lender;

        assertEq(repaidLoanDebtAfter, repaidLoanDebtBefore - 2 * 20e6);
        assertEq(compensatedLoanCreditAfter, compensatedLoanCreditBefore);
        assertTrue(lenderAfter != lenderBefore);
        assertEq(repaidLoanDebtBefore - repaidLoanDebtAfter, compensatedLoanCreditBefore);
        assertEq(repaidLoanDebtAfter, 0);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionWithDebtToRepayId)
        );
        _claim(james, creditPositionWithDebtToRepayId);

        _setPrice(0.1e18);
        assertTrue(_isUserUnderwater(bob));
        assertTrue(size.isDebtPositionLiquidatable(loanToCompensateId));

        uint256 newCreditPositionId = size.getCreditPositionIdsByDebtPositionId(loanToCompensateId)[0];

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_REPAID.selector, newCreditPositionId));
        _claim(james, newCreditPositionId);

        _repay(bob, loanToCompensateId, bob);
        _claim(james, newCreditPositionId);
    }

    function test_Compensate_compensate_simple() public {
        _setPrice(1e18);

        address[4] memory users = [alice, bob, candy, james];
        for (uint256 i = 0; i < users.length; i++) {
            _deposit(users[i], weth, 500e18);
            _deposit(users[i], usdc, 500e6);
        }
        YieldCurve memory curve = YieldCurveHelper.pointCurve(365 days, 0.1e18);
        YieldCurve memory curve2 = YieldCurveHelper.pointCurve(365 days, 0);
        _buyCreditLimit(alice, block.timestamp + 365 days, curve);
        _buyCreditLimit(bob, block.timestamp + 365 days, curve2);
        _buyCreditLimit(candy, block.timestamp + 365 days, curve2);
        _buyCreditLimit(james, block.timestamp + 365 days, curve2);
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPosition1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 loanId2 = _sellCreditMarket(candy, james, RESERVED_ID, 200e6, 365 days, false);
        uint256 creditId2 = size.getCreditPositionIdsByDebtPositionId(loanId2)[0];
        _sellCreditMarket(james, bob, creditId2, 120e6, 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(loanId2)[1];
        assertEq(size.getCreditPosition(creditPositionId).credit, 120e6);
        _compensate(bob, creditPosition1, creditPositionId, 20e6);
        assertEq(size.getCreditPosition(creditPositionId).credit, 100e6);
    }

    function test_Compensate_compensate_with_chain_of_exits() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, usdc, 100e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));

        _deposit(bob, weth, 150e18);

        uint256 debtPositionId_bob = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId_alice = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[0];

        _sellCreditMarket(alice, bob, creditPositionId_alice, 100e6, 365 days);
        uint256 creditPositionId_old_alice_now_bob = creditPositionId_alice;

        assertEq(size.getCreditPosition(creditPositionId_alice).credit, 100e6);
        assertEq(size.getCreditPosition(creditPositionId_alice).lender, bob);

        _sellCreditMarket(bob, candy, creditPositionId_old_alice_now_bob, 70e6, 365 days);
        uint256 creditPositionId_candy = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[1];

        assertEq(size.getDebtPosition(debtPositionId_bob).futureValue, 100e6);
        assertEq(size.getCreditPosition(creditPositionId_old_alice_now_bob).credit, 30e6);
        assertEq(size.getCreditPosition(creditPositionId_candy).credit, 70e6);

        _compensate(bob, creditPositionId_candy, creditPositionId_old_alice_now_bob);
        uint256 creditPositionId_old_bob_now_candy = creditPositionId_old_alice_now_bob;

        assertEq(size.getDebtPosition(debtPositionId_bob).futureValue, 70e6);
        assertEq(size.getCreditPosition(creditPositionId_old_bob_now_candy).credit, 30e6);
        assertEq(size.getCreditPosition(creditPositionId_candy).credit, 40e6);

        assertEq(size.getCreditPosition(creditPositionId_old_bob_now_candy).lender, candy);
    }

    function test_Compensate_compensate_used_to_borrower_exit_transfer_cash_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 12 days, false);
        _sellCreditLimit(candy, block.timestamp + 365 days, 0.03e18, 12 days);

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        DebtPosition memory debtPositionBefore = size.getDebtPosition(debtPositionId);
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId2 =
            _buyCreditMarket(bob, candy, debtPositionBefore.futureValue, debtPositionBefore.dueDate - block.timestamp);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(bob, creditPositionId, creditPositionId2);

        DebtPosition memory debtPositionAfter = size.getDebtPosition(debtPositionId);
        CreditPosition memory creditPositionAfter = size.getCreditPosition(creditPositionId);
        (uint256 loansAfter,) = size.getPositionsCount();

        Vars memory _after = _state();

        assertGt(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance);
        assertLt(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance);
        assertGt(_after.candy.debtBalance, _before.candy.debtBalance);
        assertLt(_after.bob.debtBalance, _before.bob.debtBalance);
        assertEq(creditPositionAfter.credit, 0);
        assertGt(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance);
        assertEq(debtPositionBefore.borrower, bob);
        assertEq(debtPositionAfter.borrower, bob);
        assertEq(_before.alice, _after.alice);
        assertEq(loansAfter, loansBefore + 1);
    }

    function test_Compensate_compensate_used_to_borrower_exit_to_self_is_possible_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        _sellCreditLimit(bob, block.timestamp + 365 days, 0.03e18, 365 days);

        Vars memory _before = _state();

        DebtPosition memory debtPositionBefore = size.getDebtPosition(debtPositionId);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        (uint256 loansBefore,) = size.getPositionsCount();

        uint256 debtPositionId2 =
            _buyCreditMarket(bob, bob, debtPositionBefore.futureValue, debtPositionBefore.dueDate - block.timestamp);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(bob, creditPositionId, creditPositionId2);

        CreditPosition memory creditPositionAfter = size.getCreditPosition(creditPositionId);
        (uint256 loansAfter,) = size.getPositionsCount();

        Vars memory _after = _state();

        assertEq(creditPositionAfter.credit, 0);
        assertEq(_before.alice, _after.alice);
        assertGt(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance);
        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance);
        assertLt(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance);
        assertEq(loansAfter, loansBefore + 1);
    }

    function test_Compensate_compensate_used_to_borrower_exit_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        _sellCreditLimit(candy, block.timestamp + 365 days, 0, 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, candy, 1.5e18 / 2, 1.5e18)
        );
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: candy,
                creditPositionId: RESERVED_ID,
                tenor: 365 days,
                amount: 200e6,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );
    }

    function test_Compensate_compensate_used_to_borrower_exit_before_tenor_1() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);

        _updateConfig("borrowATokenCap", type(uint256).max);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1500e6);
        _deposit(candy, weth, 2000e18);
        _buyCreditLimit(
            bob, block.timestamp + 365 days, [int256(0.1e18), int256(0.1e18)], [uint256(30 days), uint256(365 days)]
        );
        _sellCreditLimit(
            candy,
            block.timestamp + 365 days,
            YieldCurveHelper.customCurve(30 days, uint256(0.25e18), 73 days, uint256(0.25e18))
        );
        uint256 startDate = block.timestamp;
        uint256 tenor = 73 days;
        uint256 dueDate = startDate + 73 days;
        uint256 amount = 1000e6;
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, amount, tenor, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 apr = size.getLoanOfferAPR(bob, tenor);
        uint256 r = Math.aprToRatePerTenor(apr, tenor);
        uint256 swapFee1 = size.getSwapFee(Math.mulDivUp(futureValue, 1e18, 1e18 + r), tenor);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(_state().feeRecipient.borrowATokenBalance, swapFee1);
        assertEq(_state().alice.borrowATokenBalance, amount);

        uint256 aliceCollateralBefore = _state().alice.collateralTokenBalance;

        vm.warp(block.timestamp + 30 days);

        uint256 debtPositionId2 = _buyCreditMarket(alice, candy, futureValue, 43 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(alice, creditPositionId, creditPositionId2);

        uint256 aliceCollateralAfter = _state().alice.collateralTokenBalance;

        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(_state().alice.debtBalance, 0);
        assertEq(_state().candy.debtBalance, size.getDebtPosition(debtPositionId2).futureValue);
        assertEq(aliceCollateralAfter, aliceCollateralBefore);

        _deposit(candy, usdc, 10_000e6);
        _repay(candy, debtPositionId2, candy);
        assertEq(_state().alice.debtBalance, 0);
        assertEq(_state().candy.debtBalance, 0);
        assertEq(_state().feeRecipient.collateralTokenBalance, 0);
    }

    function test_Compensate_compensate_used_to_borrower_exit_before_tenor_does_not_overcharge_new_borrower() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);

        _updateConfig("borrowATokenCap", type(uint256).max);
        _updateConfig("swapFeeAPR", 0.1e18);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, weth, 2000e18);
        _buyCreditLimit(bob, block.timestamp + 365 days, [int256(0.1e18)], [uint256(365 days)]);
        _sellCreditLimit(
            candy,
            block.timestamp + 365 days,
            [int256(0.1e18), int256(0.1e18)],
            [uint256(365 days / 2), uint256(365 days)]
        );

        uint256 tenor = 365 days;
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 100e6, tenor, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        uint256 dt = 365 days / 2;
        vm.warp(block.timestamp + dt);

        _deposit(alice, usdc, 1000e6);

        uint256 debtPositionId2 =
            _buyCreditMarket(alice, candy, size.getDebtPosition(debtPositionId).futureValue, tenor - dt);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(alice, creditPositionId, creditPositionId2);

        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
    }

    function test_Compensate_compensate_used_to_borrower_exit_experiment() public {
        _setPrice(1e18);

        _updateConfig("borrowATokenCap", type(uint256).max);
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalance, 100e6);

        // Bob lends as limit order
        _buyCreditLimit(
            bob, block.timestamp + 10 days, [int256(0.03e18), int256(0.03e18)], [uint256(3 days), uint256(8 days)]
        );

        // Candy deposits in WETH
        _deposit(candy, weth, 200e18);

        // Candy places a borrow limit order
        _sellCreditLimit(
            candy, block.timestamp + 365 days, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]
        );

        // Alice deposits in WETH and USDC
        _deposit(alice, weth, 5000e18);
        _deposit(alice, usdc, 200e6);
        assertEq(_state().alice.borrowATokenBalance, 200e6);

        // Alice borrows from Bob's offer
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 70e6, 5 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        // Borrower (Alice) exits the loan to the offer made by Candy
        uint256 debtPositionId2 = _buyCreditMarket(alice, candy, 110e6, 5 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(alice, creditPositionId, creditPositionId2);
    }

    function test_Compensate_compensate_split_credit_must_pay_fragmentationFee() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 500e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 500e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 500e6);

        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);

        aprs[0] = 0.2e18;
        tenors[0] = 365 days;
        marketRateMultipliers[0] = 0;

        vm.prank(candy);
        size.sellCreditLimit(
            SellCreditLimitParams({
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs}),
                maxDueDate: block.timestamp + 365 days
            })
        );

        vm.prank(bob);
        size.buyCreditLimit(
            BuyCreditLimitParams({
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs}),
                maxDueDate: block.timestamp + 365 days
            })
        );

        vm.prank(alice);
        size.buyCreditLimit(
            BuyCreditLimitParams({
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs}),
                maxDueDate: block.timestamp + 365 days
            })
        );

        vm.prank(alice);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: bob,
                creditPositionId: type(uint256).max,
                tenor: 365 days,
                amount: 100e6,
                exactAmountIn: true,
                deadline: block.timestamp,
                maxAPR: type(uint256).max
            })
        );

        uint256 creditPositionId = type(uint256).max / 2;

        vm.prank(alice);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: candy,
                creditPositionId: type(uint256).max,
                amount: 100e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        Vars memory _before = _state();
        uint256 fragmentationFeeInCollateral =
            size.debtTokenAmountToCollateralTokenAmount(size.feeConfig().fragmentationFee);
        uint256 n = 10;

        for (uint256 i = 0; i < n - 1; ++i) {
            vm.prank(alice);
            size.compensate(
                CompensateParams({
                    creditPositionWithDebtToRepayId: creditPositionId,
                    creditPositionToCompensateId: creditPositionId + 1,
                    amount: 10e6
                })
            );
        }

        Vars memory _after = _state();

        assertEq(
            _after.alice.collateralTokenBalance,
            _before.alice.collateralTokenBalance - (n - 1) * fragmentationFeeInCollateral
        );
        assertEq(size.getCreditPosition(creditPositionId).credit, 10e6);
    }

    function test_Compensate_compensate_should_be_allowed_if_it_does_not_put_user_underwater() public {
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 5_000e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 500e6);
        _deposit(alice, weth, 0.5e18);
        _deposit(alice, usdc, 100e6);

        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);

        aprs[0] = 0.2e18;
        tenors[0] = 365 days;
        marketRateMultipliers[0] = 0;

        vm.prank(alice);
        size.sellCreditLimit(
            SellCreditLimitParams({
                maxDueDate: block.timestamp + 365 days,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        vm.prank(candy);
        size.sellCreditLimit(
            SellCreditLimitParams({
                maxDueDate: block.timestamp + 365 days,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        vm.prank(bob);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: type(uint256).max,
                amount: 50e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );

        uint256 creditPositionId_1 = type(uint256).max / 2;

        vm.prank(candy);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: type(uint256).max,
                amount: 300e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );

        uint256 creditPositionId_2 = creditPositionId_1 + 1;

        vm.prank(alice);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: candy,
                creditPositionId: type(uint256).max,
                amount: 50e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );

        uint256 creditPositionId_3 = creditPositionId_2 + 1;

        _setPrice(900e18);

        vm.prank(alice);
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId_1,
                creditPositionToCompensateId: creditPositionId_3,
                amount: 50e6
            })
        );
    }

    function testFuzz_Compensate_compensate_should_revert_if_it_does_not_improve_cr(uint256 price) public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 10e6);
        _updateConfig("minimumCreditBorrowAToken", 10e6);
        _updateConfig("swapFeeAPR", 0);
        _deposit(bob, weth, 200e18);
        _deposit(bob, usdc, 5_000e6);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 500e6);
        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);

        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);

        aprs[0] = 0;
        tenors[0] = 365 days;
        marketRateMultipliers[0] = 0;

        vm.prank(alice);
        size.sellCreditLimit(
            SellCreditLimitParams({
                maxDueDate: block.timestamp + 365 days,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        vm.prank(candy);
        size.sellCreditLimit(
            SellCreditLimitParams({
                maxDueDate: block.timestamp + 365 days,
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs})
            })
        );

        vm.prank(bob);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: alice,
                creditPositionId: type(uint256).max,
                amount: 30e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: true
            })
        );

        uint256 creditPositionId_1 = type(uint256).max / 2;

        vm.prank(alice);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: candy,
                creditPositionId: type(uint256).max,
                amount: 20e6,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
        (, uint256 creditPositionCount) = size.getPositionsCount();
        uint256 creditPositionToCompensateId = CREDIT_POSITION_ID_START + creditPositionCount - 1;

        price = bound(price, 1, 1e18);
        _setPrice(price);

        uint256 crBefore = size.collateralRatio(alice);

        vm.prank(alice);
        try size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId_1,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: 10e6
            })
        ) {
            uint256 crAfter = size.collateralRatio(alice);
            assertGt(crAfter, crBefore);
        } catch (bytes memory err) {
            assertIn(
                bytes4(err),
                [Errors.MUST_IMPROVE_COLLATERAL_RATIO.selector, Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector]
            );
        }
    }

    function test_Compensate_compensate_should_revert_if_it_does_not_improve_cr_concrete_revert() public {
        testFuzz_Compensate_compensate_should_revert_if_it_does_not_improve_cr(3067665046581166411735349628098);
    }

    function test_Compensate_compensate_should_revert_if_it_does_not_improve_cr_concrete_success() public {
        testFuzz_Compensate_compensate_should_revert_if_it_does_not_improve_cr(
            403631493092371811199370247613844744760271305507456038040894
        );
    }

    function test_Compensate_borrower_cannot_force_position_for_sale() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 500e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 500e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 500e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 500e6);

        int256[] memory aprs = new int256[](1);
        uint256[] memory tenors = new uint256[](1);
        uint256[] memory marketRateMultipliers = new uint256[](1);

        aprs[0] = 0.2e18;
        tenors[0] = 365 days;
        marketRateMultipliers[0] = 0;

        // Bob creates a limit order
        vm.prank(bob);
        size.buyCreditLimit(
            BuyCreditLimitParams({
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs}),
                maxDueDate: block.timestamp + 365 days
            })
        );

        uint256 amount = 100e6;

        // Alice sells credit market (borrows)
        vm.prank(alice);
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: bob,
                creditPositionId: type(uint256).max,
                tenor: 365 days,
                amount: amount,
                exactAmountIn: true,
                deadline: block.timestamp,
                maxAPR: type(uint256).max
            })
        );

        // James creates a limit order
        vm.prank(james);
        size.sellCreditLimit(
            SellCreditLimitParams({
                curveRelativeTime: YieldCurve({tenors: tenors, marketRateMultipliers: marketRateMultipliers, aprs: aprs}),
                maxDueDate: block.timestamp + 365 days
            })
        );

        uint256 creditPositionId = type(uint256).max / 2;

        // Bob's credit position is for sale
        assertTrue(size.getCreditPosition(creditPositionId).forSale);

        uint256[] memory creditPositionIds = new uint256[](1);
        creditPositionIds[0] = creditPositionId;

        // Bob sets that position as not for sale
        vm.prank(bob);
        size.setUserConfiguration(
            SetUserConfigurationParams({
                openingLimitBorrowCR: 0,
                allCreditPositionsForSaleDisabled: false,
                creditPositionIdsForSale: false,
                creditPositionIds: creditPositionIds
            })
        );

        // Bob's credit position is not for sale
        assertFalse(size.getCreditPosition(creditPositionId).forSale);
        assertEq(size.getCreditPosition(creditPositionId).credit, 100e6);
        assertEq(size.getCreditPosition(creditPositionId).lender, bob);

        uint256 newAmount = 90e6;

        // Alice has credit with newAmount
        vm.prank(alice);
        size.buyCreditMarket(
            BuyCreditMarketParams({
                borrower: james,
                creditPositionId: type(uint256).max,
                amount: newAmount,
                tenor: 365 days,
                deadline: block.timestamp,
                minAPR: 0,
                exactAmountIn: false
            })
        );
        (, uint256 creditPositionCount) = size.getPositionsCount();
        uint256 creditPositionToCompensateId = CREDIT_POSITION_ID_START + creditPositionCount - 1;

        // Alice compensates the credit position with 90% of the amount
        vm.prank(alice);
        size.compensate(
            CompensateParams({
                creditPositionWithDebtToRepayId: creditPositionId,
                creditPositionToCompensateId: creditPositionToCompensateId,
                amount: newAmount
            })
        );

        uint256 newCreditPositionId = creditPositionId + 1;

        // Bob's old credit position is not for sale and worth 10 USDC
        assertEq(size.getCreditPosition(creditPositionId).credit, amount - newAmount);
        assertEq(size.getCreditPosition(creditPositionId).lender, bob);
        assertFalse(size.getCreditPosition(creditPositionId).forSale);

        // Bob's new credit position should not be for sale and worth 90 USDC
        assertEq(size.getCreditPosition(newCreditPositionId).credit, newAmount);
        assertEq(size.getCreditPosition(creditPositionId).lender, bob);
        assertFalse(size.getCreditPosition(newCreditPositionId).forSale);
    }

    function test_Compensate_compensate_frontrunning_can_incur_in_fragmentationFee() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);

        _sellCreditLimit(alice, block.timestamp + 365 days, 0.03e18, 365 days);
        _buyCreditMarket(bob, alice, 100e6, 365 days, false);

        (, uint256 creditPositionCount) = size.getPositionsCount();
        uint256 creditPositionWithDebtToRepayId = CREDIT_POSITION_ID_START + creditPositionCount - 1;

        _sellCreditLimit(candy, block.timestamp + 365 days, 0.04e18, 365 days);
        _buyCreditMarket(alice, candy, 100e6, 365 days, false);
        (, creditPositionCount) = size.getPositionsCount();
        uint256 creditPositionToCompensateId = CREDIT_POSITION_ID_START + creditPositionCount - 1;

        uint256 snapshot = vm.snapshotState();
        {
            uint256 beforeBalance = _state().alice.collateralTokenBalance;
            _compensate(alice, creditPositionWithDebtToRepayId, creditPositionToCompensateId);
            uint256 afterBalance = _state().alice.collateralTokenBalance;
            assertEq(afterBalance, beforeBalance);
        }

        vm.revertToState(snapshot);
        _sellCreditLimit(bob, block.timestamp + 365 days, 0.04e18, 365 days);
        _buyCreditMarket(james, creditPositionWithDebtToRepayId, 50e6, false);
        {
            uint256 beforeBalance = _state().alice.collateralTokenBalance;
            _compensate(alice, creditPositionWithDebtToRepayId, creditPositionToCompensateId);
            uint256 afterBalance = _state().alice.collateralTokenBalance;
            assertLt(afterBalance, beforeBalance);
        }
    }

    function test_Compensate_borrower_forces_splitting_lender_single_credit_position_into_multiple_credit_positions()
        public
    {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0); // No swap fee for simplicity

        // 5 USDC for the fragmentation fee
        assertEq(size.feeConfig().fragmentationFee, 5e6);

        assertEq(_state().feeRecipient.borrowATokenBalance, 0);
        assertEq(_state().feeRecipient.collateralTokenBalance, 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 200e18);

        // No lending yield for simplicity
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));

        // Bob borrows Alice's 100 USDC (w/o interest for simplicity)
        uint256 debtPositionId_bob = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId_alice = size.getCreditPositionIdsByDebtPositionId(debtPositionId_bob)[0];

        // Bob maliciously splits Alice's lending liquidity (USDC) in a single source credit position into other 4 credit positions (20 USDC for each)
        // and leaves the leftover 20 USDC in the source position
        Vars memory _before = _state();

        uint256[4] memory creditPositionId_alice_splits;
        for (uint256 i = 0; i < 4; i++) {
            // Self-borrowing, no lending yield
            _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
            uint256 debtPositionId_self_borrow_bob = _sellCreditMarket(bob, bob, RESERVED_ID, 20e6, 365 days, false);
            uint256 creditPositionToCompensateId_bob =
                size.getCreditPositionIdsByDebtPositionId(debtPositionId_self_borrow_bob)[0];

            // Split Alice's source credit position
            _compensate(bob, creditPositionId_alice, creditPositionToCompensateId_bob, 20e6);
            creditPositionId_alice_splits[i] = creditPositionToCompensateId_bob;
        }

        Vars memory _after = _state();

        // Bob neither paid fragmentation fees in borrowToken (USDC) nor collateralToken (WETH)
        assertEq(_before.bob.borrowATokenBalance, _after.bob.borrowATokenBalance);
        assertEq(_before.bob.collateralTokenBalance, _after.bob.collateralTokenBalance);

        assertEq(_state().feeRecipient.borrowATokenBalance, 0);
        assertEq(_state().feeRecipient.collateralTokenBalance, 0);

        // Bob repays the source debt position's leftover (20 USDC) and all split debt positions (80 USDC in total)
        _repay(bob, size.getCreditPosition(creditPositionId_alice).debtPositionId, bob);
        for (uint256 i = 0; i < 4; i++) {
            _repay(bob, size.getCreditPosition(creditPositionId_alice_splits[i]).debtPositionId, bob);
        }

        // Alice's lending liquidity (USDC) in a single credit position was maliciously split into 5 credit positions
        assertEq(size.getCreditPosition(creditPositionId_alice).credit, 20e6);
        assertEq(size.getCreditPosition(creditPositionId_alice_splits[0]).credit, 20e6);
        assertEq(size.getCreditPosition(creditPositionId_alice_splits[1]).credit, 20e6);
        assertEq(size.getCreditPosition(creditPositionId_alice_splits[2]).credit, 20e6);
        assertEq(size.getCreditPosition(creditPositionId_alice_splits[3]).credit, 20e6);

        // Alice (or the protocol's keeper bots) must execute the claim() 5 times to aggregate her lending liquidity (USDC) back
        // -- (Scenario 1) If the protocol's keeper bots execute the claim() on behalf of Alice, this attack can drain the protocol's collected fragmentation fees
        // -- (Scenario 2) If Alice executes the claim() by herself, she will be grieved by a significant amount of claiming gas fees, and she will finally eat the loss
        _claim(alice, creditPositionId_alice);
        _claim(alice, creditPositionId_alice_splits[0]);
        _claim(alice, creditPositionId_alice_splits[1]);
        _claim(alice, creditPositionId_alice_splits[2]);
        _claim(alice, creditPositionId_alice_splits[3]);
        assertEq(_state().alice.borrowATokenBalance, 100e6); // No yield collected from Bob for simplicity
        assertEq(_state().alice.collateralTokenBalance, 0); // Further assertion

        // Again, Bob neither paid fragmentation fees in borrowToken (USDC) nor collateralToken (WETH)
        assertEq(_state().bob.borrowATokenBalance, 0); // No yield collected from self-borrowing
        assertEq(_state().bob.collateralTokenBalance, 200e18);

        assertEq(size.feeConfig().fragmentationFee, 5e6); // 5 USDC was set for the fragmentation fee
        assertEq(_state().feeRecipient.borrowATokenBalance, 0); // No collecting fragmentation fees in borrowToken (USDC)
        assertEq(_state().feeRecipient.collateralTokenBalance, 0); // No collecting fragmentation fees in collateralToken (WETH)
    }
}
