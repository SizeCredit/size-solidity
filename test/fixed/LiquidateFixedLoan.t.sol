// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {Math} from "@src/libraries/Math.sol";
import {PERCENT} from "@src/libraries/Math.sol";
import {FixedLoan, FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

contract LiquidateFixedLoanTest is BaseTest {
    function test_LiquidateFixedLoan_liquidateFixedLoan_seizes_borrower_collateral() public {
        _setPrice(1e18);

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
        uint256 debtOpening = Math.mulDivUp(debtWad, size.fixedConfig().crOpening, PERCENT);
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

        uint256 liquidatorProfit = _liquidateFixedLoan(liquidator, loanId);

        uint256 collateralRemainder = assigned - (debtWad * 5);

        Vars memory _after = _state();

        assertEq(_after.liquidator.borrowAmount, _before.liquidator.borrowAmount - debt);
        assertEq(_after.size.borrowAmount, _before.size.borrowAmount + debt);
        assertEq(_after.variablePool.borrowAmount, _before.variablePool.borrowAmount);
        assertEq(
            _after.feeRecipient.collateralAmount,
            _before.feeRecipient.collateralAmount
                + Math.mulDivDown(collateralRemainder, size.fixedConfig().collateralPremiumToProtocol, PERCENT)
        );
        uint256 collateralPremiumToBorrower =
            PERCENT - size.fixedConfig().collateralPremiumToProtocol - size.fixedConfig().collateralPremiumToLiquidator;
        assertEq(
            _after.bob.collateralAmount,
            _before.bob.collateralAmount - (debtWad * 5)
                - Math.mulDivDown(
                    collateralRemainder,
                    (size.fixedConfig().collateralPremiumToProtocol + size.fixedConfig().collateralPremiumToLiquidator),
                    PERCENT
                ),
            _before.bob.collateralAmount - (debtWad * 5) - collateralRemainder
                + Math.mulDivDown(collateralRemainder, collateralPremiumToBorrower, PERCENT)
        );
        uint256 liquidatorProfitAmount = (debtWad * 5)
            + Math.mulDivDown(collateralRemainder, size.fixedConfig().collateralPremiumToLiquidator, PERCENT);
        assertEq(_after.liquidator.collateralAmount, _before.liquidator.collateralAmount + liquidatorProfitAmount);
        assertEq(liquidatorProfit, liquidatorProfitAmount);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_repays_loan() public {
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
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.ACTIVE);

        _liquidateFixedLoan(liquidator, loanId);

        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.REPAID);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_reduces_borrower_debt() public {
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

        _setPrice(0.2e18);

        assertTrue(size.isLoanLiquidatable(loanId));

        Vars memory _before = _state();

        _liquidateFixedLoan(liquidator, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - debt, 0);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_can_be_called_unprofitably() public {
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

        assertTrue(size.isLoanLiquidatable(loanId));
        uint256 assignedCollateral = size.getFOLAssignedCollateral(loanId);
        uint256 debtWad = ConversionLibrary.amountToWad(size.getDebt(loanId), usdc.decimals());
        uint256 debtCollateral = Math.mulDivDown(debtWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidateFixedLoan(liquidator, loanId, 0);

        Vars memory _after = _state();

        assertLt(liquidatorProfit, debtCollateral);
        assertEq(liquidatorProfit, assignedCollateral);
        assertEq(_before.feeRecipient.borrowAmount, _after.feeRecipient.borrowAmount, 0);
        assertEq(_before.feeRecipient.collateralAmount, _after.feeRecipient.collateralAmount, 0);
        assertEq(size.getFOLAssignedCollateral(loanId), 0);
        assertEq(size.getUserView(bob).collateralAmount, 0);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_move_to_VP_if_overdue_and_high_CR_borrows_from_VP() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 150e18);
        _deposit(candy, address(usdc), 100e6);
        _depositVariable(alice, address(usdc), 100e6);
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        _lendAsLimitOrder(candy, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);

        vm.warp(block.timestamp + 12);

        Vars memory _before = _state();
        uint256 loansBefore = size.activeFixedLoans();
        FixedLoan memory loanBefore = size.getFixedLoan(loanId);
        uint256 variablePoolWETHBefore = weth.balanceOf(address(size.generalConfig().variablePool));

        uint256 assignedCollateral =
            Math.mulDivDown(_before.bob.collateralAmount, loanBefore.faceValue, _before.bob.debtAmount);

        _liquidateFixedLoan(liquidator, loanId);

        Vars memory _after = _state();
        uint256 loansAfter = size.activeFixedLoans();
        FixedLoan memory loanAfter = size.getFixedLoan(loanId);
        uint256 variablePoolWETHAfter = weth.balanceOf(address(size.generalConfig().variablePool));

        assertEq(_after.alice, _before.alice);
        assertEq(loansBefore, loansAfter);
        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - assignedCollateral);
        assertGt(size.variableConfig().collateralOverdueTransferFee, 0);
        assertEq(
            variablePoolWETHAfter,
            variablePoolWETHBefore + assignedCollateral - size.variableConfig().collateralOverdueTransferFee
        );
        assertTrue(!loanBefore.repaid);
        assertTrue(loanAfter.repaid);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_move_to_VP_should_claim_later_with_interest() public {
        _setPrice(1e18);
        _deposit(alice, address(usdc), 100e6);
        _deposit(bob, address(weth), 150e18);
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);

        vm.warp(block.timestamp + 12);

        FixedLoan memory loan = size.getFixedLoan(loanId);

        _liquidateFixedLoan(liquidator, loanId);

        _deposit(liquidator, address(usdc), 1_000e6);

        Vars memory _before = _state();

        _setLiquidityIndex(1.1e27);

        Vars memory _interest = _state();

        _claim(alice, loanId);

        Vars memory _after = _state();

        assertEq(_interest.alice.borrowAmount, _before.alice.borrowAmount * 1.1e27 / 1e27);
        assertEq(_after.alice.borrowAmount, _interest.alice.borrowAmount + loan.faceValue * 1.1e27 / 1e27);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_move_to_VP_fails_if_VP_does_not_have_enough_liquidity()
        internal
    {}
}
