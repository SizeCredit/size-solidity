// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Math} from "@src/libraries/Math.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

contract LiquidateTest is BaseTest {
    function test_Liquidate_liquidate_seizes_borrower_collateral() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 365 days);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtWad = ConversionLibrary.amountToWad(debt, usdc.decimals());
        uint256 debtOpening = Math.mulDivUp(debtWad, size.riskConfig().crOpening, PERCENT);
        uint256 lock = Math.mulDivUp(debtOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        // nothing is locked anymore on v2
        lock = 0;
        uint256 assigned = 100e18 - lock;

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), assigned);
        assertEq(size.getDebt(debtPositionId), debt);
        assertEq(size.collateralRatio(bob), Math.mulDivDown(assigned, PERCENT, (debtWad * 1)));
        assertTrue(!size.isUserLiquidatable(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.2e18);

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), assigned);
        assertEq(size.getDebt(debtPositionId), debt);
        assertEq(size.collateralRatio(bob), Math.mulDivDown(assigned, PERCENT, (debtWad * 5)));
        assertTrue(size.isUserLiquidatable(bob));
        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidate(liquidator, debtPositionId);

        uint256 collateralRemainder = assigned - (debtWad * 5);

        Vars memory _after = _state();

        assertEq(_after.liquidator.borrowATokenBalance, _before.liquidator.borrowATokenBalance - debt);
        assertEq(_after.size.borrowATokenBalance, _before.size.borrowATokenBalance + debt);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertEq(
            _after.feeRecipient.collateralTokenBalance,
            _before.feeRecipient.collateralTokenBalance
                + Math.mulDivDown(collateralRemainder, size.feeConfig().collateralProtocolPercent, PERCENT)
        );
        uint256 collateralPremiumToBorrower =
            PERCENT - size.feeConfig().collateralProtocolPercent - size.feeConfig().collateralLiquidatorPercent;
        assertEq(
            _after.bob.collateralTokenBalance,
            _before.bob.collateralTokenBalance - (debtWad * 5)
                - Math.mulDivDown(
                    collateralRemainder,
                    (size.feeConfig().collateralProtocolPercent + size.feeConfig().collateralLiquidatorPercent),
                    PERCENT
                ),
            _before.bob.collateralTokenBalance - (debtWad * 5) - collateralRemainder
                + Math.mulDivDown(collateralRemainder, collateralPremiumToBorrower, PERCENT)
        );
        uint256 liquidatorProfitAmount =
            (debtWad * 5) + Math.mulDivDown(collateralRemainder, size.feeConfig().collateralLiquidatorPercent, PERCENT);
        assertEq(
            _after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance + liquidatorProfitAmount
        );
        assertEq(liquidatorProfit, liquidatorProfitAmount);
    }

    function test_Liquidate_liquidate_repays_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 15e6, block.timestamp + 365 days);

        _setPrice(0.2e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        _liquidate(liquidator, debtPositionId);

        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.REPAID);
    }

    function test_Liquidate_liquidate_reduces_borrower_debt() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 365 days);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);

        uint256 repayFee = size.getDebtPosition(debtPositionId).repayFee;

        _setPrice(0.2e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        Vars memory _before = _state();

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - debt - repayFee, 0);
    }

    function test_Liquidate_liquidate_can_be_called_unprofitably() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, usdc, 1000e6);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 365 days);

        _setPrice(0.1e18);

        uint256 repayFee = size.getDebtPosition(debtPositionId).repayFee;
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));
        uint256 assignedCollateral = size.getDebtPositionAssignedCollateral(debtPositionId);
        uint256 faceValueWad =
            ConversionLibrary.amountToWad(size.getDebtPosition(debtPositionId).faceValue, usdc.decimals());
        uint256 faceValueCollateral = Math.mulDivDown(faceValueWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidate(liquidator, debtPositionId, 0);

        Vars memory _after = _state();

        assertLt(liquidatorProfit, faceValueCollateral);
        assertLt(liquidatorProfit, assignedCollateral);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance, 0);
        assertEq(
            _after.feeRecipient.collateralTokenBalance, _before.feeRecipient.collateralTokenBalance + repayFeeCollateral
        );
        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 0);
        assertEq(size.getUserView(bob).collateralTokenBalance, 0);
    }

    function test_Liquidate_liquidate_overdue_high_CR() public {
        _updateConfig("minimumMaturity", 1);
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, usdc, 1_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        _lendAsLimitOrder(candy, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 50e6, block.timestamp + 365 days);

        vm.warp(block.timestamp + 365 days + 1);

        Vars memory _before = _state();
        (uint256 loansBefore,) = size.getPositionsCount();
        assertGt(size.getDebt(debtPositionId), 0);

        uint256 assignedCollateralAfterFee = _before.bob.collateralTokenBalance
            - size.debtTokenAmountToCollateralTokenAmount(size.getDebtPosition(debtPositionId).repayFee);

        uint256 liquidatorProfitCollateralTokenFixed = size.debtTokenAmountToCollateralTokenAmount(
            size.getDebtPosition(debtPositionId).faceValue
        ) + size.feeConfig().overdueColLiquidatorFixed;

        uint256 repayFee = size.getDebtPosition(debtPositionId).repayFee;
        uint256 repayFeeCollateral = size.debtTokenAmountToCollateralTokenAmount(repayFee);

        uint256 protocolSplit = (assignedCollateralAfterFee - liquidatorProfitCollateralTokenFixed)
            * size.feeConfig().overdueColProtocolPercent / PERCENT;
        uint256 liquidatorSplit = (assignedCollateralAfterFee - liquidatorProfitCollateralTokenFixed)
            * size.feeConfig().overdueColLiquidatorPercent / PERCENT;

        _liquidate(liquidator, debtPositionId);

        Vars memory _after = _state();
        (uint256 loansAfter,) = size.getPositionsCount();

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(
            _after.bob.collateralTokenBalance,
            _before.bob.collateralTokenBalance - liquidatorProfitCollateralTokenFixed
                - (protocolSplit + liquidatorSplit) - repayFeeCollateral
        );
        assertEq(
            _after.feeRecipient.collateralTokenBalance,
            _before.feeRecipient.collateralTokenBalance + repayFeeCollateral + protocolSplit
        );
        assertEq(
            _after.liquidator.collateralTokenBalance,
            _before.liquidator.collateralTokenBalance + liquidatorProfitCollateralTokenFixed + liquidatorSplit
        );
        assertEq(size.getDebt(debtPositionId), 0);
        assertLt(_after.bob.debtBalance, _before.bob.debtBalance);
        assertEq(_after.bob.debtBalance, 0);
    }

    function test_Liquidate_liquidate_overdue_should_claim_later_with_interest() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _deposit(liquidator, usdc, 1_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 50e6, block.timestamp + 365 days);
        uint256 faceValue = size.getDebtPosition(debtPositionId).faceValue;
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        vm.warp(block.timestamp + 365 days + 1);

        _liquidate(liquidator, debtPositionId);

        Vars memory _before = _state();

        _setLiquidityIndex(1.1e27);

        Vars memory _interest = _state();

        _claim(alice, creditId);

        Vars memory _after = _state();

        assertEq(_interest.alice.borrowATokenBalance, _before.alice.borrowATokenBalance * 1.1e27 / 1e27);
        assertEq(_after.alice.borrowATokenBalance, _interest.alice.borrowATokenBalance + faceValue * 1.1e27 / 1e27);
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

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 15e6, block.timestamp + 365 days);

        _setPrice(newPrice);
        vm.warp(block.timestamp + interval);

        vm.assume(size.isDebtPositionLiquidatable(debtPositionId));

        Vars memory _before = _state();

        vm.prank(liquidator);
        try size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        ) returns (uint256 liquidatorProfitCollateralToken) {
            Vars memory _after = _state();

            assertGe(liquidatorProfitCollateralToken, minimumCollateralProfit);
            assertGe(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance);
        } catch {}
    }

    function test_Liquidate_liquidate_charge_repayFee() internal {}

    function test_Liquidate_liquidate_with_CR_100_can_be_unprofitable_due_to_repayFee() internal {}

    function testFuzz_Liquidate_liquidate_charge_repayFee() internal {}
}
