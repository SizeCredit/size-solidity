// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {Vars} from "./BaseTestGeneric.sol";

import {Math} from "@src/libraries/MathLibrary.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {FixedLoanStatus} from "@src/libraries/fixed/FixedLoanLibrary.sol";

contract LiquidateFixedLoanTest is BaseTest {
    function test_LiquidateFixedLoan_liquidateFixedLoan_seizes_borrower_collateral() public {
        _setPrice(1e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 amount = 15e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);
        uint256 debtOpening = Math.mulDivUp(debt, size.config().crOpening, PERCENT);
        uint256 lock = Math.mulDivUp(debtOpening, 10 ** priceFeed.decimals(), priceFeed.getPrice());
        // nothing is locked anymore on v2
        lock = 0;
        uint256 assigned = 100e18 - lock;

        assertEq(size.getFOLAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId), debt);
        assertEq(size.collateralRatio(bob), Math.mulDivDown(assigned, PERCENT, (debt * 1)));
        assertTrue(!size.isLiquidatable(bob));
        assertTrue(!size.isLiquidatable(loanId));

        _setPrice(0.2e18);

        assertEq(size.getFOLAssignedCollateral(loanId), assigned);
        assertEq(size.getDebt(loanId), debt);
        assertEq(size.collateralRatio(bob), Math.mulDivDown(assigned, PERCENT, (debt * 5)));
        assertTrue(size.isLiquidatable(bob));
        assertTrue(size.isLiquidatable(loanId));

        Vars memory _before = _state();

        uint256 liquidatorProfit = _liquidateFixedLoan(liquidator, loanId);

        uint256 collateralRemainder = assigned - (debt * 5);

        Vars memory _after = _state();

        assertEq(_after.liquidator.borrowAmount, _before.liquidator.borrowAmount - debt);
        assertEq(_after.protocolBorrowAmount, _before.protocolBorrowAmount + debt);
        assertEq(
            _after.feeRecipientCollateralAmount,
            _before.feeRecipientCollateralAmount
                + Math.mulDivDown(collateralRemainder, size.config().collateralPremiumToProtocol, PERCENT)
        );
        uint256 collateralPremiumToBorrower =
            PERCENT - size.config().collateralPremiumToProtocol - size.config().collateralPremiumToLiquidator;
        assertEq(
            _after.bob.collateralAmount,
            _before.bob.collateralAmount - (debt * 5)
                - Math.mulDivDown(
                    collateralRemainder,
                    (size.config().collateralPremiumToProtocol + size.config().collateralPremiumToLiquidator),
                    PERCENT
                ),
            _before.bob.collateralAmount - (debt * 5) - collateralRemainder
                + Math.mulDivDown(collateralRemainder, collateralPremiumToBorrower, PERCENT)
        );
        uint256 liquidatorProfitAmount =
            (debt * 5) + Math.mulDivDown(collateralRemainder, size.config().collateralPremiumToLiquidator, PERCENT);
        assertEq(_after.liquidator.collateralAmount, _before.liquidator.collateralAmount + liquidatorProfitAmount);
        assertEq(liquidatorProfit, liquidatorProfitAmount);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_repays_loan() public {
        _setPrice(1e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 15e18, 12);

        _setPrice(0.2e18);

        assertTrue(size.isLiquidatable(loanId));
        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.ACTIVE);

        _liquidateFixedLoan(liquidator, loanId);

        assertEq(size.getFixedLoanStatus(loanId), FixedLoanStatus.REPAID);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_reduces_borrower_debt() public {
        _setPrice(1e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 100e18, 100e18);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 amount = 15e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);

        _setPrice(0.2e18);

        assertTrue(size.isLiquidatable(loanId));

        Vars memory _before = _state();

        _liquidateFixedLoan(liquidator, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - debt, 0);
    }

    function test_LiquidateFixedLoan_liquidateFixedLoan_can_be_called_unprofitably() public {
        _setPrice(1e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);
        _deposit(liquidator, 1000e18, 1000e18);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 amount = 15e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);

        _setPrice(0.1e18);

        assertTrue(size.isLiquidatable(loanId));
        uint256 assignedCollateral = size.getFOLAssignedCollateral(loanId);
        uint256 debtCollateral = Math.mulDivDown(size.getDebt(loanId), 10 ** priceFeed.decimals(), priceFeed.getPrice());
        (uint256 feeRecipientCollateralAssetBefore, uint256 feeRecipientBorrowAssetBefore,) = size.getFeeRecipient();

        uint256 liquidatorProfit = _liquidateFixedLoan(liquidator, loanId, 0);

        (uint256 feeRecipientCollateralAssetAfter, uint256 feeRecipientBorrowAssetAfter,) = size.getFeeRecipient();

        assertLt(liquidatorProfit, debtCollateral);
        assertEq(liquidatorProfit, assignedCollateral);
        assertEq(feeRecipientBorrowAssetBefore, feeRecipientBorrowAssetAfter, 0);
        assertEq(feeRecipientCollateralAssetBefore, feeRecipientCollateralAssetAfter, 0);
        assertEq(size.getFOLAssignedCollateral(loanId), 0);
        assertEq(size.getUserView(bob).collateralAmount, 0);
    }
}
