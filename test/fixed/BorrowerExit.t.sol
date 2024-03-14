// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Math, PERCENT} from "@src/libraries/Math.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {CreditPosition, DebtPosition} from "@src/libraries/fixed/LoanLibrary.sol";
import {BorrowerExitParams} from "@src/libraries/fixed/actions/BorrowerExit.sol";

contract BorrowerExitTest is BaseTest {
    function test_BorrowerExit_borrowerExit_transfer_cash_from_sender_to_borrowOffer_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6 + size.feeConfig().earlyBorrowerExitFee);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 12 days);
        _borrowAsLimitOrder(candy, 0.03e18, block.timestamp + 12 days);

        Vars memory _before = _state();

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        DebtPosition memory debtPositionBefore = size.getDebtPosition(debtPositionId);
        CreditPosition memory creditPositionBefore = size.getCreditPosition(creditPositionId);
        (uint256 loansBefore,) = size.getPositionsCount();

        _borrowerExit(bob, debtPositionId, candy);

        DebtPosition memory debtPositionAfter = size.getDebtPosition(debtPositionId);
        CreditPosition memory creditPositionAfter = size.getCreditPosition(creditPositionId);
        (uint256 loansAfter,) = size.getPositionsCount();

        Vars memory _after = _state();

        assertGt(_after.candy.borrowATokenBalanceFixed, _before.candy.borrowATokenBalanceFixed);
        assertLt(_after.bob.borrowATokenBalanceFixed, _before.bob.borrowATokenBalanceFixed);
        assertGt(_after.candy.debtBalanceFixed, _before.candy.debtBalanceFixed);
        assertLt(_after.bob.debtBalanceFixed, _before.bob.debtBalanceFixed);
        assertEq(creditPositionAfter.credit, creditPositionBefore.credit);
        assertEq(
            _after.feeRecipient.borrowATokenBalanceFixed,
            _before.feeRecipient.borrowATokenBalanceFixed + size.feeConfig().earlyBorrowerExitFee
        );
        assertEq(debtPositionBefore.borrower, bob);
        assertEq(debtPositionAfter.borrower, candy);
        assertEq(_before.alice, _after.alice);
        assertEq(loansAfter, loansBefore);
    }

    // @audit exit to self should not change anything except for fees
    function test_BorrowerExit_borrowerExit_to_self_is_possible_properties() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6 + size.feeConfig().earlyBorrowerExitFee);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        _borrowAsLimitOrder(bob, 0.03e18, block.timestamp + 365 days);

        Vars memory _before = _state();

        address borrowerToExitTo = bob;

        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        CreditPosition memory creditPositionBefore = size.getCreditPosition(creditPositionId);
        (uint256 loansBefore,) = size.getPositionsCount();

        _borrowerExit(bob, debtPositionId, borrowerToExitTo);

        CreditPosition memory creditPositionAfter = size.getCreditPosition(creditPositionId);
        (uint256 loansAfter,) = size.getPositionsCount();

        Vars memory _after = _state();

        assertEq(creditPositionAfter.credit, creditPositionBefore.credit);
        assertEq(_before.alice, _after.alice);
        assertEq(
            _after.feeRecipient.borrowATokenBalanceFixed,
            _before.feeRecipient.borrowATokenBalanceFixed + size.feeConfig().earlyBorrowerExitFee
        );
        assertEq(_after.bob.collateralTokenBalanceFixed, _before.bob.collateralTokenBalanceFixed);
        assertEq(_after.bob.debtBalanceFixed, _before.bob.debtBalanceFixed);
        assertEq(
            _after.bob.borrowATokenBalanceFixed,
            _before.bob.borrowATokenBalanceFixed - size.feeConfig().earlyBorrowerExitFee
        );
        assertEq(loansAfter, loansBefore);
    }

    function test_BorrowerExit_borrowerExit_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(bob, usdc, 100e6 + size.feeConfig().earlyBorrowerExitFee);
        _deposit(candy, weth, 150e18);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        _borrowAsLimitOrder(candy, 0, block.timestamp + 365 days);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, candy, 1.5e18 / 2, 1.5e18)
        );
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                borrowerToExitTo: candy,
                deadline: block.timestamp,
                minAPR: 0
            })
        );
    }

    function test_BorrowerExit_borrowerExit_before_maturity() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, weth, 2000e18);
        _lendAsLimitOrder(
            bob,
            block.timestamp + 365 days,
            [
                Math.ratePerMaturityToLinearAPR(int256(0.1e18), 30 days),
                Math.ratePerMaturityToLinearAPR(int256(0.1e18), 365 days)
            ],
            [uint256(30 days), uint256(365 days)]
        );
        _borrowAsLimitOrder(
            candy,
            0,
            YieldCurveHelper.customCurve(
                30 days,
                Math.ratePerMaturityToLinearAPR(int256(0.25e18), 30 days),
                73 days,
                Math.ratePerMaturityToLinearAPR(int256(0.25e18), 73 days)
            )
        );
        uint256 startDate = block.timestamp;
        uint256 dueDate = startDate + 73 days;
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 1000e6, dueDate);
        uint256 ratePerMaturity = Math.mulDivDown(
            size.getDebtPosition(debtPositionId).faceValue, PERCENT, size.getDebtPosition(debtPositionId).issuanceValue
        ) - PERCENT;

        assertEq(size.repayFee(debtPositionId), 1e6);
        assertEq(ratePerMaturity, 0.1e18);
        assertEq(size.getDebtPosition(debtPositionId).startDate, startDate);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
        assertEq(_state().alice.debtBalanceFixed, 1101e6);

        uint256 aliceCollateralBefore = _state().alice.collateralTokenBalanceFixed;

        vm.warp(block.timestamp + 30 days);

        uint256 earlyRepayFee = Math.mulDivUp(1e6, 30 days, 73 days);
        _deposit(alice, usdc, size.feeConfig().earlyBorrowerExitFee);
        _borrowerExit(alice, debtPositionId, candy);

        uint256 aliceCollateralAfter = _state().alice.collateralTokenBalanceFixed;
        uint256 newRatePerMaturity = Math.mulDivUp(
            size.getDebtPosition(debtPositionId).faceValue, PERCENT, size.getDebtPosition(debtPositionId).issuanceValue
        ) - PERCENT;

        uint256 newIssuanceValue = Math.mulDivUp(1100e6, 1e18, 1e18 + 0.25e18);
        uint256 newRepayFee = Math.mulDivUp(0.005e18 * newIssuanceValue, 43 days, 365 days * 1e18);
        assertEq(size.repayFee(debtPositionId), newRepayFee);
        assertEqApprox(newRatePerMaturity, 0.25e18, 1e10);
        assertEq(size.getDebtPosition(debtPositionId).startDate, startDate + 30 days);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 1100e6);
        assertEq(_state().alice.debtBalanceFixed, 0);
        assertEq(_state().candy.debtBalanceFixed, 1100e6 + newRepayFee);
        assertEq(
            aliceCollateralAfter, aliceCollateralBefore - size.debtTokenAmountToCollateralTokenAmount(earlyRepayFee)
        );

        _deposit(candy, usdc, 1100e6 - 880e6 + 1 /* rounding */ );
        _repay(candy, debtPositionId);
        assertEq(_state().alice.debtBalanceFixed, 0);
        assertEq(_state().candy.debtBalanceFixed, 0);
        assertEq(_state().feeRecipient.borrowATokenBalanceFixed, size.feeConfig().earlyBorrowerExitFee);
        assertEq(
            _state().feeRecipient.collateralTokenBalanceFixed,
            size.debtTokenAmountToCollateralTokenAmount(earlyRepayFee + newRepayFee)
        );
    }

    function test_BorrowerExit_borrowerExit_before_maturity_does_not_overcharge_new_borrower() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);
        _updateConfig("earlyBorrowerExitFee", 0);
        _updateConfig("repayFeeAPR", 0.1e18);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, weth, 2000e18);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, [int256(0.1e18)], [uint256(365 days)]);
        _borrowAsLimitOrder(candy, [int256(0.1e18), int256(0.1e18)], [uint256(365 days / 2), uint256(365 days)]);

        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 365 days);

        assertEq(size.getDebtPosition(debtPositionId).faceValue, 110e6);
        assertEq(size.getDebt(debtPositionId), 120e6);
        vm.warp(block.timestamp + (365 days) / 2);

        _deposit(alice, usdc, 1000e6);
        _borrowerExit(alice, debtPositionId, candy);

        Vars memory _after = _state();

        assertEqApprox(_after.candy.borrowATokenBalanceFixed, 104.76e6, 0.01e6);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 110e6);
        assertLt(size.getDebt(debtPositionId), 120e6);
    }
}
