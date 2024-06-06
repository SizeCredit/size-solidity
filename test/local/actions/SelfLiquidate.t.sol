// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract SelfLiquidateTest is BaseTest {
    function test_SelfLiquidate_selfLiquidate_rapays_with_collateral() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 150e18);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        uint256 debtInCollateralToken =
            size.debtTokenAmountToCollateralTokenAmount(size.getDebtPosition(debtPositionId).futureValue);

        vm.expectRevert();
        _liquidate(liquidator, debtPositionId, debtInCollateralToken);

        Vars memory _before = _state();

        _selfLiquidate(alice, creditPositionId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance - 150e18, 0);
        assertEq(_after.alice.collateralTokenBalance, _before.alice.collateralTokenBalance + 150e18);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - 100e6);
    }

    function test_SelfLiquidate_selfliquidate_two_lenders() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, usdc, 150e6);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 150e6);
        _deposit(bob, weth, 200e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId1, 70e6, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(candy, james, creditPositionId2, 30e6, 365 days);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[2];

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 200e18);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 100e6);
        assertEq(size.collateralRatio(bob), 2.0e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.6e18);

        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATION_NOT_AT_LOSS.selector, creditPositionId1, 1.2e18));
        _selfLiquidate(alice, creditPositionId1);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATION_NOT_AT_LOSS.selector, creditPositionId2, 1.2e18));
        _selfLiquidate(candy, creditPositionId2);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATION_NOT_AT_LOSS.selector, creditPositionId3, 1.2e18));
        _selfLiquidate(james, creditPositionId3);
    }

    function test_SelfLiquidate_selfliquidate_keeps_accounting_in_check() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 150e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, james, RESERVED_ID, 100e6, 365 days, false);

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId), 150e18);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        uint256 futureValueInCollateralToken =
            size.debtTokenAmountToCollateralTokenAmount(size.getDebtPosition(debtPositionId).futureValue);

        vm.expectRevert();
        _liquidate(liquidator, debtPositionId, futureValueInCollateralToken);

        Vars memory _before = _state();

        _selfLiquidate(candy, creditPositionId2);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance - 150e18, 0);
        assertEq(_after.candy.collateralTokenBalance, _before.candy.collateralTokenBalance + 150e18);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - 100e6);
    }

    function test_SelfLiquidate_selfliquidate_should_not_leave_dust_loan_when_no_exits() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 200e18 - 1);
        _deposit(liquidator, usdc, 10_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        _setPrice(0.5e18);
        _selfLiquidate(alice, creditPositionId);
    }

    function test_SelfLiquidate_selfliquidate_should_not_leave_dust_loan_if_already_exited() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 150e18);
        _deposit(bob, usdc, 150e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 200e6);
        _deposit(james, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 50e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 credit = 10e6;
        _sellCreditMarket(alice, candy, creditPositionId, credit, 365 days);
        _sellCreditMarket(alice, james, RESERVED_ID, 80e6, 365 days, false);
        _sellCreditMarket(bob, james, RESERVED_ID, 40e6, 365 days, false);

        _setPrice(0.25e18);

        _selfLiquidate(alice, creditPositionId);

        assertEq(size.getDebtPosition(debtPositionId).futureValue, credit);
        assertEq(size.getCreditPosition(creditPositionId).credit, 0);
    }

    function test_SelfLiquidate_selfliquidate_should_not_leave_dust_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 300e18);
        _deposit(bob, usdc, 150e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(bob, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _buyCreditLimit(james, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, candy, creditPositionId, 49e6, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        _sellCreditMarket(candy, bob, creditPositionId2, 44e6, 365 days);
        uint256 creditPositionId3 = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[2];
        _sellCreditMarket(alice, james, RESERVED_ID, 60e6, 365 days, false);
        _sellCreditMarket(candy, james, RESERVED_ID, 80e6, 365 days, false);

        _setPrice(0.25e18);

        _selfLiquidate(candy, creditPositionId2);

        assertEq(size.getCreditPosition(creditPositionId2).credit, 0);

        _selfLiquidate(bob, creditPositionId3);

        assertEq(size.getCreditPosition(creditPositionId3).credit, 0);
    }

    function test_SelfLiquidate_selfliquidateLoan_should_work() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("fragmentationFee", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 150e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, 30e6, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertEq(size.getDebtPositionAssignedCollateral(debtPositionId1), 150e18);
        assertEq(size.getDebtPosition(debtPositionId1).futureValue, 100e6);
        assertEq(size.getCreditPosition(creditPositionId1).credit, 70e6);
        assertEq(size.collateralRatio(alice), 1.5e18);
        assertTrue(!size.isUserUnderwater(bob));
        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);
        assertEq(size.collateralRatio(alice), 0.75e18);
        _selfLiquidate(candy, creditPositionId1);
        _selfLiquidate(james, creditPositionId2);
    }

    function test_SelfLiquidate_selfliquidateLoan_insufficient_debt_token_repay_fee() public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 200e18);
        _deposit(candy, weth, 200e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 150e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, 30e6, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_insufficient_debt_token_no_fees(uint256 exitAmount) public {
        _updateConfig("fragmentationFee", 0);
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 150e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken + size.feeConfig().fragmentationFee,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken - size.feeConfig().fragmentationFee
        );
        uint256 swapFee = size.getSwapFee(exitAmount, 365 days);
        vm.assume(exitAmount > swapFee + size.feeConfig().fragmentationFee);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, borrowAmount, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, exitAmount, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.4e18);

        _selfLiquidate(candy, creditPositionId1);

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_compensate_used_to_borrower_exit(uint256 exitAmount) public {
        _setPrice(1e18);

        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, weth, 400e18);
        _deposit(james, usdc, 150e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken + size.feeConfig().fragmentationFee,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken - size.feeConfig().fragmentationFee
        );
        uint256 swapFee = size.getSwapFee(exitAmount, 365 days);
        vm.assume(exitAmount > swapFee + size.feeConfig().fragmentationFee);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _sellCreditLimit(james, 0, 365 days);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, borrowAmount, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, exitAmount, 365 days);
        uint256 creditPositionId12 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        _setPrice(0.5e18 - 1);

        _selfLiquidate(candy, creditPositionId1);
        uint256 debtPositionId2 =
            _buyCreditMarket(alice, james, borrowAmount - size.feeConfig().fragmentationFee, 365 days);
        uint256 creditPositionId21 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _compensate(alice, creditPositionId12, creditPositionId21);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_repay(uint256 exitAmount) public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 150e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken + size.feeConfig().fragmentationFee,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken - size.feeConfig().fragmentationFee
        );
        uint256 swapFee = size.getSwapFee(exitAmount, 365 days);
        vm.assume(exitAmount > swapFee + size.feeConfig().fragmentationFee);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _sellCreditLimit(james, 0, 365 days);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, borrowAmount, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, exitAmount, 365 days);

        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);
        _repay(alice, debtPositionId1);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_liquidate(uint256 exitAmount) public {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, weth, 200e18);
        _deposit(james, usdc, 150e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken + size.feeConfig().fragmentationFee,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken - size.feeConfig().fragmentationFee
        );
        uint256 swapFee = size.getSwapFee(exitAmount, 365 days);
        vm.assume(exitAmount > swapFee + size.feeConfig().fragmentationFee);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _sellCreditLimit(james, 0, 365 days);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, borrowAmount, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, exitAmount, 365 days);

        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);
        _deposit(liquidator, usdc, 10_000e6);
        _liquidate(liquidator, debtPositionId1);
    }

    function testFuzz_SelfLiquidate_selfliquidateLoan_creditPosition_insufficient_debt_token_fees(uint256 exitAmount)
        public
    {
        _setPrice(1e18);
        _deposit(alice, weth, 200e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, usdc, 150e6);

        uint256 borrowAmount = 100e6;
        exitAmount = bound(
            exitAmount,
            size.riskConfig().minimumCreditBorrowAToken + size.feeConfig().fragmentationFee,
            borrowAmount - size.riskConfig().minimumCreditBorrowAToken - size.feeConfig().fragmentationFee
        );
        uint256 swapFee = size.getSwapFee(exitAmount, 365 days);
        vm.assume(exitAmount > swapFee + size.feeConfig().fragmentationFee);

        _buyCreditLimit(alice, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(candy, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);
        _buyCreditLimit(james, block.timestamp + 365 days, [int256(0)], [uint256(365 days)]);

        uint256 debtPositionId1 = _sellCreditMarket(alice, candy, RESERVED_ID, borrowAmount, 365 days, false);
        uint256 creditPositionId1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        _sellCreditMarket(candy, james, creditPositionId1, exitAmount, 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];

        assertTrue(!size.isDebtPositionLiquidatable(debtPositionId1));
        _setPrice(0.5e18);

        _selfLiquidate(candy, creditPositionId1);

        assertTrue(size.isUserUnderwater(alice));
        _selfLiquidate(james, creditPositionId2);
    }

    function test_SelfLiquidate_selfLiquidate_repay() public {
        _setPrice(1e18);
        _deposit(bob, usdc, 150e6);
        _buyCreditLimit(bob, block.timestamp + 6 days, YieldCurveHelper.pointCurve(6 days, 0.03e18));
        _deposit(alice, weth, 200e18);
        uint256 debtPositionId = _sellCreditMarket(alice, bob, RESERVED_ID, 100e6, 6 days, false);

        vm.warp(block.timestamp + 1 days);

        _setPrice(0.3e18);

        assertTrue(size.isUserUnderwater(alice));
        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        _selfLiquidate(bob, size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0]);

        assertGt(_state().bob.collateralTokenBalance, 0);
        assertEq(size.getDebtPosition(debtPositionId).futureValue, 0);
    }
}
