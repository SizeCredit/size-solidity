// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {LiquidateParams} from "@src/market/libraries/actions/Liquidate.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {LoanStatus, RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {Math} from "@src/market/libraries/Math.sol";
import {PERCENT} from "@src/market/libraries/Math.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract LiquidateTest is BaseTest {
    function test_Liquidate_liquidate_repays_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 15e6, 365 days, false);

        _setPrice(0.2e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        _liquidate(liquidator, debtPositionId);

        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
    }

    function test_Liquidate_liquidate_pays_liquidator_reward() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, usdc, 80e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 1_000e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.25e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 80e6, 365 days, false);

        assertEq(_state().bob.debtBalance, 100e6);

        _setPrice(0.8e18);
        assertEq(size.collateralRatio(bob), 1.2e18);

        Vars memory _before = _state();

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance + Math.mulDivUp(105e18, 1e18, 0.8e18)
        );
    }

    function test_Liquidate_liquidate_reduces_borrower_debt() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 amount = 15e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);

        _setPrice(0.2e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        _liquidate(liquidator, debtPositionId);

        assertEq(_state().bob.debtBalance, 0);
    }

    function test_Liquidate_liquidate_can_be_called_unprofitably_and_liquidator_is_senior_creditor() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, usdc, 1000e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 amount = 15e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        _setPrice(0.1e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));
        uint256 assignedCollateral = size.getDebtPositionAssignedCollateral(debtPositionId);
        uint256 futureValueCollateral =
            size.debtTokenAmountToCollateralTokenAmount(size.getDebtPosition(debtPositionId).futureValue);

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertLt(liquidatorProfit, futureValueCollateral);
        assertEq(liquidatorProfit, assignedCollateral);
        assertEq(
            _after.feeRecipient.borrowTokenBalance,
            _before.feeRecipient.borrowTokenBalance,
            size.getSwapFee(Math.mulDivUp(futureValue, 1e18, 1.03e18), 365 days)
        );
        assertEq(
            _after.feeRecipient.collateralTokenBalance,
            _before.feeRecipient.collateralTokenBalance,
            "The liquidator receives the collateral remainder first"
        );
        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 0);
        assertEq(size.getUserView(bob).collateralTokenBalance, 0);
    }

    function test_Liquidate_liquidate_overdue_well_collateralized() public {
        _updateConfig("minTenor", 1);
        _updateConfig("maxTenor", 10 * 365 days);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("overdueCollateralProtocolPercent", 0.123e18);
        _updateConfig("crLiquidation", 1.2e18);
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, usdc, 1_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 50e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        vm.warp(block.timestamp + 365 days + 1);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertTrue(!_isUserUnderwater(bob));
        assertEq(size.collateralRatio(bob), 1.5e18);

        uint256 debtInCollateralToken = size.debtTokenAmountToCollateralTokenAmount(futureValue);
        uint256 liquidatorReward = Math.min(
            _before.bob.collateralTokenBalance - debtInCollateralToken,
            Math.mulDivUp(debtInCollateralToken, size.feeConfig().liquidationRewardPercent, PERCENT)
        );
        uint256 liquidatorProfitCollateralToken = debtInCollateralToken + liquidatorReward;

        uint256 protocolSplit = Math.min(
            _before.bob.collateralTokenBalance - liquidatorProfitCollateralToken,
            debtInCollateralToken * (size.riskConfig().crLiquidation - PERCENT) / PERCENT
        ) * size.feeConfig().overdueCollateralProtocolPercent / PERCENT;

        assertTrue(!_isUserUnderwater(bob));
        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(
            _after.bob.collateralTokenBalance,
            _before.bob.collateralTokenBalance - liquidatorProfitCollateralToken - protocolSplit
        );
        assertEq(
            _after.feeRecipient.collateralTokenBalance, _before.feeRecipient.collateralTokenBalance + protocolSplit
        );
        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance + liquidatorProfitCollateralToken
        );
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertLt(_after.bob.debtBalance, _before.bob.debtBalance);
        assertEq(_after.bob.debtBalance, 0);
    }

    function test_Liquidate_liquidate_overdue_very_high_CR() public {
        _updateConfig("minTenor", 1);
        _updateConfig("swapFeeAPR", 0);
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 1000e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, usdc, 1_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 50e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        vm.warp(block.timestamp + 365 days + 1);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 100e6);
        assertEq(size.collateralRatio(bob), 10e18);

        uint256 assignedCollateral = _before.bob.collateralTokenBalance;

        uint256 debtInCollateralToken = size.debtTokenAmountToCollateralTokenAmount(futureValue);
        uint256 liquidatorReward = Math.min(
            _state().bob.collateralTokenBalance - debtInCollateralToken,
            Math.mulDivUp(debtInCollateralToken, size.feeConfig().liquidationRewardPercent, PERCENT)
        );
        uint256 liquidatorProfitCollateralToken = debtInCollateralToken + liquidatorReward;

        uint256 collateralRemainder = Math.min(
            assignedCollateral - liquidatorProfitCollateralToken,
            Math.mulDivDown(debtInCollateralToken, size.riskConfig().crLiquidation - PERCENT, PERCENT)
        );

        uint256 protocolSplit = collateralRemainder * size.feeConfig().overdueCollateralProtocolPercent / PERCENT;

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(
            _after.bob.collateralTokenBalance,
            _before.bob.collateralTokenBalance - liquidatorProfitCollateralToken - protocolSplit
        );
        assertEq(
            _after.feeRecipient.collateralTokenBalance, _before.feeRecipient.collateralTokenBalance + protocolSplit
        );
        assertEq(liquidatorProfitCollateralToken, (100 + 5) * 1e18);
        assertEq(protocolSplit, 0.3e18, 0.01e18 * 30e18 / 1e18);
        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance + liquidatorProfitCollateralToken
        );
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertLt(_after.bob.debtBalance, _before.bob.debtBalance);
        assertEq(_after.bob.debtBalance, 0);
    }

    function test_Liquidate_liquidate_overdue_should_claim_later_with_interest() public {
        _updateConfig("swapFeeAPR", 0);
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 170e18);
        _deposit(liquidator, usdc, 1_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 50e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.warp(block.timestamp + 365 days + 1);

        _liquidate(liquidator, debtPositionId);

        Vars memory _before = _state();

        _setLiquidityIndex(1.1e27);

        Vars memory _interest = _state();

        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_interest.alice.borrowTokenBalance, _before.alice.borrowTokenBalance * 1.1e27 / 1e27);
        assertEq(_after.alice.borrowTokenBalance, _interest.alice.borrowTokenBalance + futureValue * 1.1e27 / 1e27);
    }

    function test_Liquidate_liquidate_overdue_underwater() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 165e18);
        _deposit(liquidator, usdc, 1_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 50e6, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        vm.warp(block.timestamp + 365 days + 1);
        Vars memory _before = _state();

        _setPrice(0.75e18);

        uint256 debtInCollateralToken = size.debtTokenAmountToCollateralTokenAmount(futureValue);
        uint256 liquidatorReward = Math.min(
            _state().bob.collateralTokenBalance - debtInCollateralToken,
            Math.mulDivUp(debtInCollateralToken, size.feeConfig().liquidationRewardPercent, PERCENT)
        );
        uint256 liquidatorProfitCollateralToken = debtInCollateralToken + liquidatorReward;

        assertTrue(_isUserUnderwater(bob));
        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance + liquidatorProfitCollateralToken
        );
    }

    function testFuzz_Liquidate_liquidate_minimumCollateralProfit(
        uint256 newPrice,
        uint256 interval,
        uint256 minimumCollateralProfit
    ) public {
        _setPrice(1e18);
        newPrice = bound(newPrice, 1, 2e18);
        interval = bound(interval, 0, 2 * 365 days);
        minimumCollateralProfit = bound(minimumCollateralProfit, 1, 200e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 200e18);
        _deposit(liquidator, usdc, 1_000e6);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 15e6, 365 days, false);

        _setPrice(newPrice);
        vm.warp(block.timestamp + interval);

        vm.assume(size.isDebtPositionLiquidatable(debtPositionId));

        Vars memory _before = _state();

        vm.prank(liquidator);
        try size.liquidate(
            LiquidateParams({
                debtPositionId: debtPositionId,
                minimumCollateralProfit: minimumCollateralProfit,
                deadline: type(uint256).max
            })
        ) returns (uint256 liquidatorProfitCollateralToken) {
            Vars memory _after = _state();

            assertGe(liquidatorProfitCollateralToken, minimumCollateralProfit);
            assertGe(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance);
        } catch {}
    }

    function test_Liquidate_example() public {
        _setPrice(1e18);
        _deposit(bob, usdc, 150e6);
        _buyCreditLimit(bob, block.timestamp + 6 days, YieldCurveHelper.pointCurve(6 days, 0.03e18));
        _deposit(alice, weth, 200e18);
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 100e6, 6 days, false);
        assertGe(size.collateralRatio(alice), size.riskConfig().crOpening);
        assertTrue(!_isUserUnderwater(alice), "borrower should not be underwater");
        vm.warp(block.timestamp + 1 days);
        _setPrice(0.6e18);

        assertTrue(_isUserUnderwater(alice), "borrower should be underwater");
        assertTrue(size.isDebtPositionLiquidatable(debtPositionId), "loan should be liquidatable");

        _deposit(liquidator, usdc, 10_000e6);
        _liquidate(liquidator, debtPositionId);
    }

    function test_Liquidate_overdue_experiment() public {
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowTokenBalance, 100e6);

        // Bob lends as limit order
        _buyCreditLimit(
            bob, block.timestamp + 5 days, [int256(0.03e18), int256(0.03e18)], [uint256(3 days), uint256(8 days)]
        );

        // Alice deposits in WETH
        _deposit(alice, weth, 50e18);

        // Alice borrows as market order from Bob
        _sellCreditMarket(alice, bob, RESERVED_ID, 70e6, 5 days, false);

        // Move forward the clock as the loan is overdue
        vm.warp(block.timestamp + 6 days);

        // Assert loan conditions
        assertEq(size.getLoanStatus(0), LoanStatus.OVERDUE, "Loan should be overdue");
        (uint256 debtPositionsCount, uint256 creditPositionsCount) = size.getPositionsCount();
        assertEq(debtPositionsCount, 1);
        assertEq(creditPositionsCount, 1);

        assertGt(size.getDebtPosition(0).futureValue, 0, "Loan should not be repaid before moving to the variable pool");
        uint256 aliceCollateralBefore = _state().alice.collateralTokenBalance;
        assertEq(aliceCollateralBefore, 50e18, "Alice should have no locked ETH initially");

        // add funds
        _deposit(liquidator, usdc, 1_000e6);

        // Liquidate Overdue
        _liquidate(liquidator, 0);

        uint256 aliceCollateralAfter = _state().alice.collateralTokenBalance;

        // Assert post-overdue liquidation conditions
        assertEq(size.getDebtPosition(0).futureValue, 0, "Loan should be repaid by moving into the variable pool");
        assertLt(
            aliceCollateralAfter,
            aliceCollateralBefore,
            "Alice should have lost some collateral after the overdue liquidation"
        );
    }

    function test_Liquidate_round_up_should_not_DoS(uint256 price, uint256 collateral) public {
        collateral = bound(collateral, 0, 100e18);
        price = bound(price, 0.1e18, 1e18);
        _setPrice(1e18);
        _deposit(bob, usdc, 150e6);
        _buyCreditLimit(bob, block.timestamp + 6 days, YieldCurveHelper.pointCurve(6 days, 0.03e18));
        _deposit(alice, weth, 200e18 + collateral);
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 100e6, 6 days, false);
        assertGe(size.collateralRatio(alice), size.riskConfig().crOpening);
        assertTrue(!_isUserUnderwater(alice), "borrower should not be underwater");
        _setPrice(price);

        if (_isUserUnderwater(alice)) {
            _deposit(liquidator, usdc, 10_000e6);
            _liquidate(liquidator, debtPositionId);
        }
    }
}
