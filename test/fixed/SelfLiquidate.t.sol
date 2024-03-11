// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Math} from "@src/libraries/Math.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

contract SelfLiquidateTest is BaseTest {
    function test_SelfLiquidate_selfliquidate_rapays_with_collateral() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 150e18);
        assertEq(size.getDebt(debtPositionId), 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserLiquidatable(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        uint256 debtBorrowTokenWad =
            ConversionLibrary.amountToWad(size.getDebtPosition(debtPositionId).faceValue, usdc.decimals());
        uint256 debtInCollateralToken =
            Math.mulDivDown(debtBorrowTokenWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        vm.expectRevert();
        _liquidate(liquidator, debtPositionId, debtInCollateralToken);

        Vars memory _before = _state();

        _selfLiquidate(alice, creditPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralBalance, _before.bob.collateralBalance - 150e18, 0);
        assertEq(_after.alice.collateralBalance, _before.alice.collateralBalance + 150e18);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - 100e6);
    }

    function test_SelfLiquidate_selfliquidate_CreditPosition_keeps_accounting_in_check() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
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
        assertEq(size.getDebt(debtPositionId), 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserLiquidatable(bob));
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

        assertEq(_after.bob.collateralBalance, _before.bob.collateralBalance - 150e18, 0);
        assertEq(_after.candy.collateralBalance, _before.candy.collateralBalance + 150e18);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - 100e6);
    }

    function test_SelfLiquidate_selfliquidate_DebtPosition_should_not_leave_dust_loan_when_no_exits() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _setPrice(0.0001e18);
        _selfLiquidate(alice, creditPositionId);
    }

    function test_SelfLiquidate_selfliquidate_DebtPosition_should_not_leave_dust_loan_when_exits() public {
        _setPrice(1e18);

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
        uint256 repayFee = size.repayFee(debtPositionId);
        _borrowAsMarketOrder(alice, candy, 5e6, block.timestamp + 365 days, [creditPositionId]);
        _borrowAsMarketOrder(alice, james, 80e6, block.timestamp + 365 days);
        _borrowAsMarketOrder(bob, james, 40e6, block.timestamp + 365 days);

        _setPrice(0.25e18);

        assertEq(size.getDebtPosition(debtPositionId).faceValue, 50e6);
        assertEq(size.getDebt(debtPositionId), 50e6 + repayFee);
        assertEq(size.getCreditPosition(creditPositionId).credit, 50e6 - 5e6);
        assertEq(size.getCreditPosition(creditPositionId).credit, 45e6);

        _selfLiquidate(alice, creditPositionId);

        assertLt(size.repayFee(debtPositionId), repayFee, "Repay fee is adjusted after self liquidation");
        assertGt(size.repayFee(debtPositionId), 0);
        assertEq(size.getDebt(debtPositionId), 5e6 + size.repayFee(debtPositionId));
        assertEq(size.getCreditPosition(creditPositionId).credit, 0);
        assertEq(size.getCreditPosition(creditPositionId).credit, 0);
    }

    function test_SelfLiquidate_selfliquidate_CreditPosition_should_not_leave_dust_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(bob, weth, 300e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6 + size.config().earlyLenderExitFee);
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
}
