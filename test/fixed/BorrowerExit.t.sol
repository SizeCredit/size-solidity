// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
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

        assertGt(_after.candy.borrowATokenBalance, _before.candy.borrowATokenBalance);
        assertLt(_after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance);
        assertGt(_after.candy.debtBalance, _before.candy.debtBalance);
        assertLt(_after.bob.debtBalance, _before.bob.debtBalance);
        assertEq(creditPositionAfter.credit, creditPositionBefore.credit);
        assertEq(
            _after.feeRecipient.borrowATokenBalance,
            _before.feeRecipient.borrowATokenBalance + size.feeConfig().earlyBorrowerExitFee
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
            _after.feeRecipient.borrowATokenBalance,
            _before.feeRecipient.borrowATokenBalance + size.feeConfig().earlyBorrowerExitFee
        );
        assertEq(_after.bob.collateralTokenBalance, _before.bob.collateralTokenBalance);
        assertEq(_after.bob.debtBalance, _before.bob.debtBalance);
        assertEq(
            _after.bob.borrowATokenBalance, _before.bob.borrowATokenBalance - size.feeConfig().earlyBorrowerExitFee
        );
        assertEq(loansAfter, loansBefore);
    }

    function test_BorrowerExit_borrowerExit_cannot_leave_borrower_liquidatable() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
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

    function test_BorrowerExit_borrowerExit_before_maturity_1() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);

        _updateConfig("borrowATokenCap", type(uint256).max);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, weth, 2000e18);
        _lendAsLimitOrder(
            bob, block.timestamp + 365 days, [int256(0.1e18), int256(0.1e18)], [uint256(30 days), uint256(365 days)]
        );
        _borrowAsLimitOrder(candy, YieldCurveHelper.customCurve(30 days, uint256(0.25e18), 73 days, uint256(0.25e18)));
        uint256 startDate = block.timestamp;
        uint256 dueDate = startDate + 73 days;
        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 1000e6, dueDate);
        uint256 apr = size.getAPR(debtPositionId);

        assertEq(size.getDebtPosition(debtPositionId).repayFee, 1e6);
        assertEq(apr, 0.1e18);
        assertEq(size.getDebtPosition(debtPositionId).startDate, startDate);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);

        uint256 aliceCollateralBefore = _state().alice.collateralTokenBalance;

        vm.warp(block.timestamp + 30 days);

        uint256 earlyRepayFee = Math.mulDivDown(1e6, 30 days, 73 days);
        _deposit(alice, usdc, size.feeConfig().earlyBorrowerExitFee);
        _borrowerExit(alice, debtPositionId, candy);

        uint256 aliceCollateralAfter = _state().alice.collateralTokenBalance;
        uint256 newAPR = size.getAPR(debtPositionId);
        uint256 newFaceValue = size.getDebtPosition(debtPositionId).faceValue;

        uint256 newIssuanceValue = size.getDebtPosition(debtPositionId).issuanceValue;
        uint256 newRepayFee = Math.mulDivDown(0.005e18 * newIssuanceValue, 43 days, 365 days * 1e18) + 1;
        assertEq(size.getDebtPosition(debtPositionId).repayFee, newRepayFee);
        assertEqApprox(newAPR, 0.25e18, 1e10);
        assertEq(size.getDebtPosition(debtPositionId).startDate, startDate + 30 days);
        assertEq(size.getDebtPosition(debtPositionId).dueDate, dueDate);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, newFaceValue);
        assertEq(_state().alice.debtBalance, 0);
        assertEq(_state().candy.debtBalance, newFaceValue + newRepayFee);
        assertEq(
            aliceCollateralAfter, aliceCollateralBefore - size.debtTokenAmountToCollateralTokenAmount(earlyRepayFee)
        );

        _deposit(candy, usdc, 10_000e6);
        _repay(candy, debtPositionId);
        assertEq(_state().alice.debtBalance, 0);
        assertEq(_state().candy.debtBalance, 0);
        assertEq(_state().feeRecipient.borrowATokenBalance, size.feeConfig().earlyBorrowerExitFee);
        assertEq(
            _state().feeRecipient.collateralTokenBalance,
            size.debtTokenAmountToCollateralTokenAmount(earlyRepayFee + newRepayFee)
        );
    }

    function test_BorrowerExit_borrowerExit_before_maturity_does_not_overcharge_new_borrower() public {
        _setPrice(1e18);
        vm.warp(block.timestamp + 12345 days);

        _updateConfig("borrowATokenCap", type(uint256).max);
        _updateConfig("earlyBorrowerExitFee", 0);
        _updateConfig("repayFeeAPR", 0.1e18);
        _updateConfig("overdueLiquidatorReward", 0);
        _deposit(alice, weth, 2000e18);
        _deposit(bob, usdc, 1000e6);
        _deposit(candy, weth, 2000e18);
        _lendAsLimitOrder(bob, block.timestamp + 365 days, [int256(0.1e18)], [uint256(365 days)]);
        _borrowAsLimitOrder(candy, [int256(0.1e18), int256(0.1e18)], [uint256(365 days / 2), uint256(365 days)]);

        uint256 debtPositionId = _borrowAsMarketOrder(alice, bob, 100e6, block.timestamp + 365 days);

        assertEq(size.getDebtPosition(debtPositionId).faceValue, 110e6);
        assertEq(size.getOverdueDebt(debtPositionId), 120e6);
        vm.warp(block.timestamp + (365 days) / 2);

        _deposit(alice, usdc, 1000e6);
        _borrowerExit(alice, debtPositionId, candy);

        Vars memory _after = _state();

        assertEqApprox(_after.candy.borrowATokenBalance, 104.76e6, 0.01e6);
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 110e6);
        assertLt(size.getOverdueDebt(debtPositionId), 120e6);
    }

    function test_BorrowerExit_borrowerExit_experiment() public {
        _setPrice(1e18);

        _updateConfig("borrowATokenCap", type(uint256).max);
        // Bob deposits in USDC
        _deposit(bob, usdc, 100e6);
        assertEq(_state().bob.borrowATokenBalance, 100e6);

        // Bob lends as limit order
        _lendAsLimitOrder(
            bob, block.timestamp + 10 days, [int256(0.03e18), int256(0.03e18)], [uint256(3 days), uint256(8 days)]
        );

        // Candy deposits in WETH
        _deposit(candy, weth, 200e18);

        // Candy places a borrow limit order
        _borrowAsLimitOrder(candy, [int256(0.03e18), int256(0.03e18)], [uint256(5 days), uint256(12 days)]);

        // Alice deposits in WETH and USDC
        _deposit(alice, weth, 5000e18);
        _deposit(alice, usdc, 200e6);
        assertEq(_state().alice.borrowATokenBalance, 200e6);

        // Alice borrows from Bob's offer
        _borrowAsMarketOrder(alice, bob, 70e6, block.timestamp + 5 days);

        // Borrower (Alice) exits the loan to the offer made by Candy
        _borrowerExit(alice, 0, candy);
    }
}
