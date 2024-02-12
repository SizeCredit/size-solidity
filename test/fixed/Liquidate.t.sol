// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Math} from "@src/libraries/Math.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {Loan, LoanLibrary, LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";

contract LiquidateTest is BaseTest {
    using LoanLibrary for DebtPosition;
    using LoanLibrary for CreditPosition;

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

        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 amount = 15e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtWad = ConversionLibrary.amountToWad(debt, usdc.decimals());
        uint256 debtOpening = Math.mulDivUp(debtWad, size.config().crOpening, PERCENT);
        uint256 lock = Math.mulDivUp(debtOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        // nothing is locked anymore on v2
        lock = 0;
        uint256 assigned = 100e18 - lock;

        assertEq(size.getFOLAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId), debt);
        assertEq(size.collateralRatio(bob), Math.mulDivDown(assigned, PERCENT, (debtWad * 1)));
        assertTrue(!size.isUserLiquidatable(bob));
        assertTrue(!size.isLoanLiquidatable(loanId));

        _setPrice(0.2e18);

        assertEq(size.getFOLAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId), debt);
        assertEq(size.collateralRatio(bob), Math.mulDivDown(assigned, PERCENT, (debtWad * 5)));
        assertTrue(size.isUserLiquidatable(bob));
        assertTrue(size.isLoanLiquidatable(loanId));

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidate(liquidator, loanId);

        uint256 collateralRemainder = assigned - (debtWad * 5);

        Vars memory _after = _state();

        assertEq(_after.liquidator.borrowAmount, _before.liquidator.borrowAmount - debt);
        assertEq(_after.size.borrowAmount, _before.size.borrowAmount + debt);
        assertEq(_after.variablePool.borrowAmount, _before.variablePool.borrowAmount);
        assertEq(
            _after.feeRecipient.collateralAmount,
            _before.feeRecipient.collateralAmount
                + Math.mulDivDown(collateralRemainder, size.config().collateralSplitProtocolPercent, PERCENT)
        );
        uint256 collateralPremiumToBorrower =
            PERCENT - size.config().collateralSplitProtocolPercent - size.config().collateralSplitLiquidatorPercent;
        assertEq(
            _after.bob.collateralAmount,
            _before.bob.collateralAmount - (debtWad * 5)
                - Math.mulDivDown(
                    collateralRemainder,
                    (size.config().collateralSplitProtocolPercent + size.config().collateralSplitLiquidatorPercent),
                    PERCENT
                ),
            _before.bob.collateralAmount - (debtWad * 5) - collateralRemainder
                + Math.mulDivDown(collateralRemainder, collateralPremiumToBorrower, PERCENT)
        );
        uint256 liquidatorProfitAmount = (debtWad * 5)
            + Math.mulDivDown(collateralRemainder, size.config().collateralSplitLiquidatorPercent, PERCENT);
        assertEq(_after.liquidator.collateralAmount, _before.liquidator.collateralAmount + liquidatorProfitAmount);
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

        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e6, 12);

        _setPrice(0.2e18);

        assertTrue(size.isLoanLiquidatable(loanId));
        assertEq(size.getLoanStatus(loanId), LoanStatus.ACTIVE);

        _liquidate(liquidator, loanId);

        assertEq(size.getLoanStatus(loanId), LoanStatus.REPAID);
    }

    function test_Liquidate_liquidate_reduces_borrower_debt() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);

        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 amount = 15e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);

        uint256 repayFee = size.repayFee(loanId);

        _setPrice(0.2e18);

        assertTrue(size.isLoanLiquidatable(loanId));

        Vars memory _before = _state();

        _liquidate(liquidator, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - debt - repayFee, 0);
    }

    function test_Liquidate_liquidate_can_be_called_unprofitably() public {
        _setPrice(1e18);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, usdc, 1000e6);

        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 amount = 15e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);

        _setPrice(0.1e18);

        uint256 repayFee = size.repayFee(loanId);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertTrue(size.isLoanLiquidatable(loanId));
        uint256 assignedCollateral = size.getFOLAssignedCollateral(loanId);
        uint256 faceValueWad = ConversionLibrary.amountToWad(size.faceValue(loanId), usdc.decimals());
        uint256 faceValueCollateral = Math.mulDivDown(faceValueWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidate(liquidator, loanId, 0);

        Vars memory _after = _state();

        assertLt(liquidatorProfit, faceValueCollateral);
        assertLt(liquidatorProfit, assignedCollateral);
        assertEq(_after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount, 0);
        assertEq(_after.feeRecipient.collateralAmount, _before.feeRecipient.collateralAmount + repayFeeCollateral);
        assertEq(size.getFOLAssignedCollateral(loanId), 0);
        assertEq(size.getUserView(bob).collateralAmount, 0);
    }

    function test_Liquidate_liquidate_move_to_VP_if_overdue_and_high_CR_borrows_from_VP() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 160e18);
        _deposit(candy, address(usdc), 100e6);
        _depositVariable(alice, address(usdc), 100e6);
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);

        vm.warp(block.timestamp + 12);

        Vars memory _before = _state();
        uint256 loansBefore = size.activeLoans();
        Loan memory loanBefore = size.getLoan(loanId);
        assertGt(size.getDebt(loanId), 0);
        uint256 variablePoolWETHBefore = weth.balanceOf(address(size.data().variablePool));

        uint256 assignedCollateralAfterFee = Math.mulDivDown(
            _before.bob.collateralAmount, loanBefore.faceValue(), (_before.bob.debtAmount - size.repayFee(loanId))
        );

        uint256 repayFee = size.partialRepayFee(loanId, loanBefore.faceValue());
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        _liquidate(liquidator, loanId);

        Vars memory _after = _state();
        uint256 loansAfter = size.activeLoans();
        uint256 variablePoolWETHAfter = weth.balanceOf(address(size.data().variablePool));

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - assignedCollateralAfterFee);
        assertGt(size.config().collateralOverdueTransferFee, 0);
        assertEq(_after.feeRecipient.collateralAmount, _before.feeRecipient.collateralAmount + repayFeeCollateral);
        assertEq(
            variablePoolWETHAfter,
            variablePoolWETHBefore + assignedCollateralAfterFee - size.config().collateralOverdueTransferFee
                - repayFeeCollateral
        );
        assertEq(size.getDebt(loanId), 0);
        assertLt(_after.bob.debtAmount, _before.bob.debtAmount);
        assertEq(_after.bob.debtAmount, 0);
    }

    function test_Liquidate_liquidate_move_to_VP_should_claim_later_with_interest() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 160e18);
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);

        vm.warp(block.timestamp + 12);

        Loan memory loan = size.getLoan(loanId);

        _liquidate(liquidator, loanId);

        _deposit(liquidator, address(usdc), 1_000e6);

        Vars memory _before = _state();

        _setLiquidityIndex(1.1e27);

        Vars memory _interest = _state();

        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_interest.alice.borrowAmount, _before.alice.borrowAmount * 1.1e27 / 1e27);
        assertEq(_after.alice.borrowAmount, _interest.alice.borrowAmount + loan.faceValue() * 1.1e27 / 1e27);
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

        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e6, 12);

        _setPrice(newPrice);
        vm.warp(block.timestamp + interval);

        vm.assume(size.isLoanLiquidatable(loanId));

        Vars memory _before = _state();

        vm.prank(liquidator);
        try size.liquidate(LiquidateParams({loanId: loanId, minimumCollateralProfit: minimumCollateralProfit}))
        returns (uint256 liquidatorProfitCollateralToken) {
            Vars memory _after = _state();

            assertGe(liquidatorProfitCollateralToken, minimumCollateralProfit);
            assertGe(_after.liquidator.collateralAmount, _before.liquidator.collateralAmount);
        } catch {}
    }

    function test_Liquidate_liquidate_move_to_VP_fails_if_VP_does_not_have_enough_liquidity() internal {}

    function test_Liquidate_liquidate_charge_repayFee() internal {}

    function test_Liquidate_liquidate_with_CR_100_can_be_unprofitable_due_to_repayFee() internal {}

    function testFuzz_Liquidate_liquidate_charge_repayFee() internal {}
}
