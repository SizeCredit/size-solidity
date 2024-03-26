// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

contract SelfLiquidateTest is BaseTest {
    function test_SelfLiquidate_selfliquidate_rapays_with_collateral() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 150e18);
        assertEq(size.getOverdueDebt(debtPositionId), 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        uint256 debtInCollateralToken =
            size.debtTokenAmountToCollateralTokenAmount(size.getDebtPosition(debtPositionId).faceValue);

        vm.expectRevert();
        _liquidate(liquidator, debtPositionId, debtInCollateralToken);

        Vars memory _before = _state();

        _selfLiquidate(alice, creditPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance - 150e18, 0);
        assertEq(_after.alice.collateralTokenBalance, _before.alice.collateralTokenBalance + 150e18);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - 100e6);
    }

    function test_SelfLiquidate_selfliquidate_CreditPosition_keeps_accounting_in_check() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, candy, 100e6, block.timestamp + 365 days, [creditPositionId]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _borrowAsMarketOrder(alice, james, 100e6, block.timestamp + 365 days);

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 150e18);
        assertEq(size.getOverdueDebt(debtPositionId), 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        uint256 faceValueInCollateralToken =
            size.debtTokenAmountToCollateralTokenAmount(size.getDebtPosition(debtPositionId).faceValue);

        vm.expectRevert();
        _liquidate(liquidator, debtPositionId, faceValueInCollateralToken);

        Vars memory _before = _state();

        _selfLiquidate(candy, creditPositionId2);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance - 150e18, 0);
        assertEq(_after.candy.collateralTokenBalance, _before.candy.collateralTokenBalance + 150e18);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - 100e6);
    }

    function test_SelfLiquidate_selfliquidate_DebtPosition_should_not_leave_dust_loan_when_no_exits() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 200e18 - 1);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _setPrice(0.5e18);
        _selfLiquidate(alice, creditPositionId);
    }

    function test_SelfLiquidate_selfliquidate_DebtPosition_should_not_leave_dust_loan_when_exits() public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(james, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 50e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 repayFee = size.getDebtPosition(debtPositionId).repayFee;
        _borrowAsMarketOrder(alice, candy, 5e6, block.timestamp + 365 days, [creditPositionId]);
        _borrowAsMarketOrder(alice, james, 80e6, block.timestamp + 365 days);
        _borrowAsMarketOrder(bob, james, 40e6, block.timestamp + 365 days);

        _setPrice(0.25e18);

        assertEq(size.getDebtPosition(debtPositionId).faceValue, 50e6);
        assertEq(size.getOverdueDebt(debtPositionId), 50e6 + repayFee);
        assertEq(size.getCreditPosition(creditPositionId).credit, 50e6 - 5e6);
        assertEq(size.getCreditPosition(creditPositionId).credit, 45e6);

        _selfLiquidate(alice, creditPositionId);

        assertLt(
            size.getDebtPosition(debtPositionId).repayFee, repayFee, "Repay fee is adjusted after self liquidation"
        );
        assertGt(size.getDebtPosition(debtPositionId).repayFee, 0);
        assertEq(size.getOverdueDebt(debtPositionId), 5e6 + size.getDebtPosition(debtPositionId).repayFee);
        assertEq(size.getCreditPosition(creditPositionId).credit, 0);
        assertEq(size.getCreditPosition(creditPositionId).credit, 0);
    }

    function test_SelfLiquidate_selfliquidate_CreditPosition_should_not_leave_dust_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 300e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 0);
        _lendAsLimitOrder(james, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, candy, 49e6, block.timestamp + 365 days, [creditPositionId]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _borrowAsMarketOrder(candy, bob, 44e6, block.timestamp + 365 days, [creditPositionId2]);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[2];
        _borrowAsMarketOrder(alice, james, 60e6, block.timestamp + 365 days);
        _borrowAsMarketOrder(candy, james, 80e6, block.timestamp + 365 days);

        _setPrice(0.25e18);

        _selfLiquidate(candy, creditPositionId2);

        assertEq(size.getCreditPosition(creditPositionId2).credit, 0);

        _selfLiquidate(bob, creditPositionId3);

        assertEq(size.getCreditPosition(creditPositionId3).credit, 0);
    }

    function test_SelfLiquidate_selfliquidateLoan_creditPosition_should_work() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("earlyLenderExitFee", 0);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _borrowAsMarketOrder(candy, james, 30e6, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId1), 150e18);
        assertEq(size.getOverdueDebt(debtPositionId1), 100e6);
        assertEq(size.getCreditPosition(creditPositionId1).credit, 70e6);
        assertEq(size.collateralRatio(alice), 1.5e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);
        assertEq(size.collateralRatio(alice), 0.75e18);
        _selfLiquidate(candy, creditPositionId1);
        _selfLiquidate(james, creditPositionId2);
    }

    function test_SelfLiquidate_selfliquidateLoan_creditPosition_insufficient_debt_token_repay_fee() public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 200e18);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _borrowAsMarketOrder(candy, james, 30e6, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_creditPosition_insufficient_debt_token_repay_fee_no_fees(
        uint256 exitAmount
    ) public {
        _updateConfig("earlyLenderExitFee", 0);
        _updateConfig("repayFeeAPR", 0);
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken
        );

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.4e18);

        _selfLiquidate(candy, creditPositionId1);

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);
    }

    function test_SelfLiquidate_selfliquidateLoan_selfLiquidateLoan() public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        uint256 exitAmount = 5.000001e6;

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 id = _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(id, type(uint256).max);
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        assertEq(size.getUserView(alice).debtBalance, 100.5e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.5e6);

        _selfLiquidate(candy, creditPositionId1);

        assertEq(size.getUserView(alice).debtBalance, 5.025002e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.025001e6);
        assertEq(size.getCreditPosition(creditPositionId2).credit, 5.000001e6);
        assertEq(
            size.getUserView(alice).debtBalance,
            size.getDebtPosition(debtPositionId1).repayFee + size.getCreditPosition(creditPositionId2).credit
                + size.feeConfig().overdueLiquidatorReward
        );

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);

        assertEq(size.getUserView(alice).debtBalance, 0);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_borrowerExit(uint256 exitAmount) public {
        _setPrice(1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 300e18);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken
        );

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _borrowAsLimitOrder(james, 0, block.timestamp + 365 days);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);

        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);
        _borrowerExit(alice, debtPositionId1, james);
    }

    function test_SelfLiquidate_selfliquidateLoan_borrowerExit_round_fees_down() public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        uint256 exitAmount = 5.000001e6;

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _borrowAsLimitOrder(james, 0, block.timestamp + 365 days);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 id = _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(id, type(uint256).max);
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        assertEq(size.getUserView(alice).debtBalance, 100.5e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.5e6);

        _selfLiquidate(candy, creditPositionId1);

        assertEq(size.getUserView(alice).debtBalance, 5.025002e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.025001e6);
        assertEq(size.getCreditPosition(creditPositionId2).credit, 5.000001e6);
        assertEq(
            size.getUserView(alice).debtBalance,
            size.getDebtPosition(debtPositionId1).repayFee + size.getCreditPosition(creditPositionId2).credit
                + size.feeConfig().overdueLiquidatorReward
        );

        _borrowerExit(alice, debtPositionId1, james);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_repay(uint256 exitAmount) public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken
        );

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _borrowAsLimitOrder(james, 0, block.timestamp + 365 days);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 id = _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);

        assertEq(id, type(uint256).max);
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);
        _repay(alice, debtPositionId1);
    }

    function test_SelfLiquidate_selfliquidateLoan_repay_round_fees_down() public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        uint256 exitAmount = 5.000001e6;

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _borrowAsLimitOrder(james, 0, block.timestamp + 365 days);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 id = _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(id, type(uint256).max);
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        assertEq(size.getUserView(alice).debtBalance, 100.5e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.5e6);

        _selfLiquidate(candy, creditPositionId1);

        assertEq(size.getUserView(alice).debtBalance, 5.025002e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.025001e6);
        assertEq(size.getCreditPosition(creditPositionId2).credit, 5.000001e6);
        assertEq(
            size.getUserView(alice).debtBalance,
            size.getDebtPosition(debtPositionId1).repayFee + size.getCreditPosition(creditPositionId2).credit
                + size.feeConfig().overdueLiquidatorReward
        );

        _repay(alice, debtPositionId1);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_liquidate(uint256 exitAmount) public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken
        );

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _borrowAsLimitOrder(james, 0, block.timestamp + 365 days);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);

        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);
        _deposit(liquidator, usdc, 10_000e6);
        _liquidate(liquidator, debtPositionId1);
    }

    function test_SelfLiquidate_selfliquidateLoan_liquidate_round_fees_down() public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        uint256 exitAmount = 5.000001e6;

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _borrowAsLimitOrder(james, 0, block.timestamp + 365 days);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 id = _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(id, type(uint256).max);
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        assertEq(size.getUserView(alice).debtBalance, 100.5e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.5e6);

        _selfLiquidate(candy, creditPositionId1);

        assertEq(size.getUserView(alice).debtBalance, 5.025002e6 + 10e6);
        assertEq(size.getDebtPosition(debtPositionId1).repayFee, 0.025001e6);
        assertEq(size.getCreditPosition(creditPositionId2).credit, 5.000001e6);
        assertEq(
            size.getUserView(alice).debtBalance,
            size.getDebtPosition(debtPositionId1).repayFee + size.getCreditPosition(creditPositionId2).credit
                + size.feeConfig().overdueLiquidatorReward
        );

        _deposit(liquidator, usdc, 10_000e6);
        _liquidate(liquidator, debtPositionId1);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_creditPosition_insufficient_debt_token_repay_fee_2(
        uint256 exitAmount
    ) public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken
        );

        _lendAsLimitOrder(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _lendAsLimitOrder(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _borrowAsMarketOrder(alice, candy, borrowAmount, block.timestamp + 365 days);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 id = _borrowAsMarketOrder(candy, james, exitAmount, block.timestamp + 365 days, [creditPositionId1]);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(id, type(uint256).max);
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);
    }

    function test_SelfLiquidate_selfLiquidate_repay() public {
        _setPrice(1e18);
        _deposit(bob, usdc, 100e6);
        _lendAsLimitOrder(bob, block.timestamp + 6 days, 0.03e18);
        _deposit(alice, weth, 200e18);
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 6 days);

        vm.warp(block.timestamp + 1 days);

        _setPrice(0.3e18);

        assertTrue(size.isUserUnderwater(alice));
        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        _selfLiquidate(bob, size.getCreditPositionIdsByDebtPositionId(0)[0]);

        assertGt(_state().bob.collateralTokenBalance, 0);
        assertEq(size.getOverdueDebt(debtPositionId), 0);
    }
}
