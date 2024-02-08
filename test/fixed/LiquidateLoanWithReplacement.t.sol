// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Math} from "@src/libraries/Math.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {Loan, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

import {LiquidateLoanWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateLoanWithReplacement.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateLoanWithReplacementTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setKeeperRole(liquidator);
    }

    function test_LiquidateLoanWithReplacement_liquidateLoanWithReplacement_updates_new_borrower_borrowOffer_same_rate()
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
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _borrowAsLimitOrder(candy, 0.03e18, 12);
        uint256 amount = 15e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 faceValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 repayFee = size.maximumRepayFee(loanId);
        uint256 delta = faceValue - amount;

        _setPrice(0.2e18);

        Loan memory loanBefore = size.getLoan(loanId);
        Vars memory _before = _state();

        assertEq(loanBefore.generic.borrower, bob);
        assertGt(size.getDebt(loanId), 0);
        assertEq(size.getLoanStatus(loanId), LoanStatus.ACTIVE);

        _liquidateLoanWithReplacement(liquidator, loanId, candy);

        Loan memory loanAfter = size.getLoan(loanId);
        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.candy.debtAmount, _before.candy.debtAmount + faceValue + repayFee);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + amount);
        assertEq(_after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount + delta);
        assertEq(loanAfter.generic.borrower, candy);
        assertGt(size.getDebt(loanId), 0);
        assertEq(size.getLoanStatus(loanId), LoanStatus.ACTIVE);
    }

    function test_LiquidateLoanWithReplacement_liquidateLoanWithReplacement_updates_new_borrower_borrowOffer_different_rate(
    ) public {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 400e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _borrowAsLimitOrder(candy, 0.01e18, 12);
        uint256 amount = 15e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 faceValue = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 newAmount = Math.mulDivDown(faceValue, PERCENT, (PERCENT + 0.01e18));
        uint256 repayFee = size.maximumRepayFee(loanId);
        uint256 delta = faceValue - newAmount;

        _setPrice(0.2e18);

        Loan memory loanBefore = size.getLoan(loanId);
        Vars memory _before = _state();

        assertEq(loanBefore.generic.borrower, bob);
        assertGt(size.getDebt(loanId), 0);
        assertEq(size.getLoanStatus(loanId), LoanStatus.ACTIVE);

        _liquidateLoanWithReplacement(liquidator, loanId, candy);

        Loan memory loanAfter = size.getLoan(loanId);
        Vars memory _after = _state();

        assertEq(_after.alice, _before.alice);
        assertEq(_after.candy.debtAmount, _before.candy.debtAmount + faceValue + repayFee);
        assertEq(_after.candy.borrowAmount, _before.candy.borrowAmount + newAmount);
        assertEq(_before.variablePool.borrowAmount, 0);
        assertEq(_after.variablePool.borrowAmount, _before.variablePool.borrowAmount);
        assertEq(_after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount + delta);
        assertEq(loanAfter.generic.borrower, candy);
        assertGt(size.getDebt(loanId), 0);
        assertEq(size.getLoanStatus(loanId), LoanStatus.ACTIVE);
    }

    function test_LiquidateLoanWithReplacement_liquidateLoanWithReplacement_cannot_leave_new_borrower_liquidatable()
        public
    {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _borrowAsLimitOrder(candy, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e6, 12);

        _setPrice(0.2e18);

        vm.startPrank(liquidator);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.COLLATERAL_RATIO_BELOW_RISK_COLLATERAL_RATIO.selector, candy, 0, 1.5e18)
        );
        size.liquidateLoanWithReplacement(
            LiquidateLoanWithReplacementParams({loanId: loanId, borrower: candy, minimumCollateralRatio: 1e18})
        );
    }

    function test_LiquidateLoanWithReplacement_liquidateLoanWithReplacement_cannot_be_executed_if_loan_is_overdue()
        public
    {
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        _borrowAsLimitOrder(candy, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e6, 12);

        _setPrice(0.2e18);

        assertTrue(size.isLoanLiquidatable(loanId));

        vm.startPrank(liquidator);

        vm.warp(block.timestamp + 12);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.INVALID_LOAN_STATUS.selector, loanId, LoanStatus.OVERDUE, LoanStatus.ACTIVE)
        );
        size.liquidateLoanWithReplacement(
            LiquidateLoanWithReplacementParams({loanId: loanId, borrower: candy, minimumCollateralRatio: 1e18})
        );
    }
}
