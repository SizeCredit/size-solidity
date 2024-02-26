// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Math} from "@src/libraries/Math.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";

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
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 400e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _borrowAsLimitOrder(candy, 0.03e18, block.timestamp + 12 days);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 12 days);
        uint256 faceValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 repayFee = size.repayFee(debtPositionId);
        uint256 delta = faceValue - amount;

        _setPrice(0.2e18);

        Vars memory _before = _state();

        assertEq(size.getDebtPosition(debtPositionId).borrower, bob);
        assertGt(size.getDebt(debtPositionId), 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        _liquidateWithReplacement(liquidator, debtPositionId, candy);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.candy.debtAmount, _before.candy.debtAmount + faceValue + repayFee);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + amount);
        assertEq(_after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount + delta);
        assertEq(size.getDebtPosition(debtPositionId).borrower, candy);
        assertGt(size.getDebt(debtPositionId), 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_updates_new_borrower_borrowOffer_different_rate()
        public
    {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 400e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _borrowAsLimitOrder(candy, 0.01e18, block.timestamp + 12 days);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 12 days);
        uint256 faceValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 newAmount = Math.mulDivDown(faceValue, PERCENT, (PERCENT + 0.01e18));
        uint256 repayFee = size.repayFee(debtPositionId);
        uint256 delta = faceValue - newAmount;

        _setPrice(0.2e18);

        Vars memory _before = _state();

        assertEq(size.getDebtPosition(debtPositionId).borrower, bob);
        assertGt(size.getDebt(debtPositionId), 0);
        assertEq(size.getLoanStatus(debtPositionId), LoanStatus.ACTIVE);

        _liquidateWithReplacement(liquidator, debtPositionId, candy);

        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.candy.debtAmount, _before.candy.debtAmount + faceValue + repayFee);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + newAmount);
        assertEq(_before.variablePool.borrowAmount, 0);
        assertEq(_after.variablePool.borrowAmount, _before.variablePool.borrowAmount);
        assertEq(_after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount + delta);
        assertEq(size.getDebtPosition(debtPositionId).borrower, candy);
        assertGt(size.getDebt(debtPositionId), 0);
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
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _borrowAsLimitOrder(candy, 0.03e18, block.timestamp + 12 days);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 15e6, block.timestamp + 12 days);

        _setPrice(0.2e18);

        vm.startPrank(liquidator);

        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, candy, 0, 1.5e18));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                deadline: block.timestamp,
                minRate: 0,
                minimumCollateralProfit: 0
            })
        );
    }

    function test_LiquidateWithReplacement_liquidateWithReplacement_cannot_be_executed_if_loan_is_overdue() public {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _borrowAsLimitOrder(candy, 0.03e18, 30);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 15e6, block.timestamp + 12 days);

        _setPrice(0.2e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        vm.startPrank(liquidator);

        vm.warp(block.timestamp + 12 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, block.timestamp + 12 days));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                deadline: block.timestamp,
                minRate: 0,
                minimumCollateralProfit: 0
            })
        );
    }
}
