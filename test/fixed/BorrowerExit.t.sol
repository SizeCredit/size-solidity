// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

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
        _deposit(bob, usdc, 100e6 + size.config().earlyBorrowerExitFee);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _borrowAsLimitOrder(candy, 0.03e18, 12);

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

        assertGt(_after.candy.borrowAmount, _before.candy.borrowAmount);
        assertLt(_after.bob.borrowAmount, _before.bob.borrowAmount);
        assertGt(_after.candy.debtAmount, _before.candy.debtAmount);
        assertLt(_after.bob.debtAmount, _before.bob.debtAmount);
        assertEq(creditPositionAfter.credit, creditPositionBefore.credit);
        assertEq(
            _after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount + size.config().earlyBorrowerExitFee
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
        _deposit(bob, usdc, 100e6 + size.config().earlyBorrowerExitFee);
        _lendAsLimitOrder(alice, 12, 0.03e18, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _borrowAsLimitOrder(bob, 0.03e18, 12);

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
            _after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount + size.config().earlyBorrowerExitFee
        );
        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount);
        assertEq(_after.bob.borrowAmount, _before.bob.borrowAmount - size.config().earlyBorrowerExitFee);
        assertEq(loansAfter, loansBefore);
    }

    function test_BorrowerExit_borrowerExit_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(bob, usdc, 100e6 + size.config().earlyBorrowerExitFee);
        _deposit(candy, weth, 150e18);
        _lendAsLimitOrder(alice, 12, 1e18, 12);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        _borrowAsLimitOrder(candy, 0, 12);

        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, candy, 1.5e18 / 2, 1.5e18)
        );
        size.borrowerExit(
            BorrowerExitParams({
                debtPositionId: debtPositionId,
                borrowerToExitTo: candy,
                deadline: block.timestamp,
                minRate: 0
            })
        );
    }

    function test_BorrowerExit_borrowerExit_before_maturity() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);
        _updateConfig("earlyBorrowerExitFee", 0);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, weth, 2000e18);
        _lendAsLimitOrder(
            bob, block.timestamp + 365 days, [int256(0.1e18), int256(0.1e18)], [uint256(30 days), uint256(365 days)]
        );
        _borrowAsLimitOrder(candy, 0, YieldCurveHelper.customCurve(30 days, 0, 365 days, 0));
        uint256 startDate = block.timestamp;
        uint256 dueDate = startDate + 73 days;
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 1000e6, dueDate);

        assertEq(size.repayFee(debtPositionId), 1e6);
        assertEq(size.getDebtPosition(debtPositionId).rate, 0.1e18);
        assertEq(size.getDebtPosition(debtPositionId).startDate, startDate);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
        assertEq(_state().alice.debtAmount, 1101e6);

        vm.warp(block.timestamp + 30 days);

        _deposit(alice, usdc, 100e6 + 1e6); // interest + fee
        _borrowerExit(alice, debtPositionId, candy);

        assertEq(size.repayFee(debtPositionId), 1e6);
        assertEq(size.getDebtPosition(debtPositionId).rate, 0.1e18);
        // assertEq(size.getDebtPosition(debtPositionId).startDate, startDate + 30 days);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
        assertEq(_state().alice.debtAmount, 0);
        assertEq(_state().candy.debtAmount, 1101e6);

        _repay(candy, debtPositionId);
        assertEq(_state().alice.debtAmount, 0);
        assertEq(_state().candy.debtAmount, 0);
    }
}
