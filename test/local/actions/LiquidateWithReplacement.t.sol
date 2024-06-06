// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {DebtPosition} from "@src/libraries/LoanLibrary.sol";
import {Math} from "@src/libraries/Math.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/actions/LiquidateWithReplacement.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateWithReplacementTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setKeeperRole(liquidator);
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_updates_new_borrower_borrowOffer_same_rate()
        public
    {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("liquidationRewardPercent", 0.1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 400e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _sellCreditLimit(candy, 0.03e18, 365 days);
        uint256 amount = 15e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 delta = futureValue - amount;

        _setPrice(0.2e18);

        Vars memory _before = _state();

        assertEq(size.getDebtPosition(debtPositionId).borrower, bob);
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        _liquidateWithReplacement(liquidator, debtPositionId, candy);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.candy.debtBalance, _before.candy.debtBalance + futureValue);
        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance + amount);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance + delta);
        assertEq(size.getDebtPosition(debtPositionId).borrower, candy);
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_updates_new_borrower_borrowOffer_different_rate()
        public
    {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 400e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _sellCreditLimit(candy, 0.01e18, 365 days);
        uint256 amount = 15e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 newAmount = Math.mulDivDown(futureValue, PERCENT, (PERCENT + 0.01e18));
        uint256 delta = futureValue - newAmount;

        _setPrice(0.2e18);

        Vars memory _before = _state();

        assertEq(size.getDebtPosition(debtPositionId).borrower, bob);
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        _liquidateWithReplacement(liquidator, debtPositionId, candy);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.candy.debtBalance, _before.candy.debtBalance + futureValue);
        assertEq(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance + newAmount);
        assertEq(_before.variablePool.borrowATokenBalance, 0);
        assertEq(_after.variablePool.borrowATokenBalance, _before.variablePool.borrowATokenBalance);
        assertEq(_after.feeRecipient.borrowATokenBalance, _before.feeRecipient.borrowATokenBalance + delta);
        assertEq(size.getDebtPosition(debtPositionId).borrower, candy);
        assertGt(size.getDebtPosition(debtPositionId).futureValue, 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_cannot_leave_new_borrower_liquidatable() public {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _sellCreditLimit(candy, 0.03e18, 365 days);
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 15e6, 365 days, false);

        _setPrice(0.2e18);

        vm.startPrank(liquidator);

        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, candy, 0, 1.5e18));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                deadline: block.timestamp,
                minAPR: 0,
                minimumCollateralProfit: 0
            })
        );
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_cannot_be_executed_if_loan_is_overdue() public {
        _updateConfig("minTenor", 1);
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.03e18));
        _sellCreditLimit(candy, 0.03e18, 30);
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 15e6, 365 days, false);

        _setPrice(0.2e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        vm.startPrank(liquidator);

        vm.warp(block.timestamp + 365 days + 1);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, debtPositionId));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                deadline: block.timestamp,
                minAPR: 0,
                minimumCollateralProfit: 0
            })
        );
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_experiment() public {
        _setPrice(1e18);

        _updateConfig("borrowATokenCap", type(uint256).max);
        // Bob deposits in USDC
        _deposit(bob, usdc, 150e6);

        // Bob lends as limit order
        _buyCreditLimit(
            bob,
            block.timestamp + 365 days,
            [int256(0.03e18), int256(0.03e18)],
            [uint256(365 days), uint256(365 days * 2)]
        );

        // Alice deposits in WETH
        _deposit(alice, weth, 200e18);

        // Alice borrows as market order from Bob
        _sellCreditMarket(alice, bob, RESERVED_ID, 100e6, 365 days, false);

        // Assert conditions for Alice's borrowing
        assertGe(size.collateralRatio(alice), size.riskConfig().crOpening, "Alice should be above CR opening");
        assertTrue(!size.isUserUnderwater(alice), "Borrower should not be underwater");

        // Candy places a borrow limit order (candy needs more collateral so that she can be replaced later)
        _deposit(candy, weth, 20000e18);
        assertEq(_state().candy.collateralTokenBalance, 20000e18);
        _sellCreditLimit(candy, [int256(0.03e18), int256(0.03e18)], [uint256(180 days), uint256(365 days * 2)]);

        // Update the context (time and price)
        vm.warp(block.timestamp + 1 days);
        _setPrice(0.6e18);

        // Assert conditions for liquidation
        assertTrue(size.isUserUnderwater(alice), "Borrower should be underwater");
        assertTrue(size.isDebtPositionLiquidatable(0), "Loan should be liquidatable");

        DebtPosition memory loan = size.getDebtPosition(0);
        assertEq(loan.borrower, alice, "Alice should be the borrower");
        assertEq(_state().alice.debtBalance, loan.futureValue, "Alice should have the debt");

        assertEq(_state().candy.debtBalance, 0, "Candy should have no debt");
        // Perform the liquidation with replacement
        _deposit(liquidator, usdc, 10_000e6);
        _liquidateWithReplacement(liquidator, 0, candy);
        assertEq(_state().alice.debtBalance, 0, "Alice should have no debt after");
        loan = size.getDebtPosition(0);
        assertEq(_state().candy.debtBalance, loan.futureValue, "Candy should have the debt after");
    }
}
