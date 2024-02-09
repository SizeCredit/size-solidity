// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Loan, LoanLibrary} from "@src/libraries/fixed/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

contract SelfLiquidateLoanTest is BaseTest {
    using LoanLibrary for Loan;

    function test_SelfLiquidateLoan_selfliquidateLoan_rapays_with_collateral() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);

        assertEq(size.getFOLAssignedCollateral(loanId), 150e18);
        assertEq(size.getDebt(loanId), 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserLiquidatable(bob));
        assertTrue(!size.isLoanLiquidatable(loanId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        vm.expectRevert();
        _liquidateLoan(liquidator, loanId);

        Vars memory _before = _state();

        _selfLiquidateLoan(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - 150e18, 0);
        assertEq(_after.alice.collateralAmount, _before.alice.collateralAmount + 150e18);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - 100e6);
    }

    function test_SelfLiquidateLoan_selfliquidateLoan_SOL_keeps_accounting_in_check() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(bob, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(candy, 12, 0, 12);
        _lendAsLimitOrder(james, 12, 0, 12);
        uint256 folId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 100e6, 12, [folId]);
        _borrowAsMarketOrder(alice, james, 100e6, 12);

        assertEq(size.getFOLAssignedCollateral(folId), 150e18);
        assertEq(size.getDebt(folId), 100e6);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isUserLiquidatable(bob));
        assertTrue(!size.isLoanLiquidatable(folId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        vm.expectRevert();
        _liquidateLoan(liquidator, folId);

        Vars memory _before = _state();

        _selfLiquidateLoan(candy, solId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - 150e18, 0);
        assertEq(_after.candy.collateralAmount, _before.candy.collateralAmount + 150e18);
        assertEq(_after.feeRecipient.borrowAmount, _before.feeRecipient.borrowAmount);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - 100e6);
    }

    function test_SelfLiquidateLoan_selfliquidateLoan_FOL_should_not_leave_dust_loan_when_no_exits() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);

        _setPrice(0.0001e18);
        _selfLiquidateLoan(alice, loanId);
    }

    function test_SelfLiquidateLoan_selfliquidateLoan_FOL_should_not_leave_dust_loan_when_exits() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(james, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(bob, 12, 0, 12);
        _lendAsLimitOrder(candy, 12, 0, 12);
        _lendAsLimitOrder(james, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e6, 12);
        uint256 repayFee = size.repayFee(loanId);
        _borrowAsMarketOrder(alice, candy, 5e6, 12, [loanId]);
        _borrowAsMarketOrder(alice, james, 80e6, 12);
        _borrowAsMarketOrder(bob, james, 40e6, 12);

        _setPrice(0.25e18);

        assertEq(size.getLoan(loanId).faceValue(), 50e6);
        assertEq(size.getDebt(loanId), 50e6 + repayFee);
        assertEq(size.getCredit(loanId), 50e6 - 5e6);
        assertEq(size.getCredit(loanId), 45e6);

        _selfLiquidateLoan(alice, loanId);

        assertEq(size.getDebt(loanId), 5e6 + repayFee);
        assertEq(size.getCredit(loanId), 0);
        assertEq(size.getCredit(loanId), 0);
    }

    function test_SelfLiquidateLoan_selfliquidateLoan_SOL_should_not_leave_dust_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(bob, weth, 300e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6 + size.config().earlyLenderExitFee);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _lendAsLimitOrder(bob, 12, 0, 12);
        _lendAsLimitOrder(candy, 12, 0, 12);
        _lendAsLimitOrder(james, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e6, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 49e6, 12, [loanId]);
        uint256 solId2 = _borrowAsMarketOrder(candy, bob, 44e6, 12, [solId]);
        _borrowAsMarketOrder(alice, james, 60e6, 12);
        _borrowAsMarketOrder(candy, james, 80e6, 12);

        _setPrice(0.25e18);

        _selfLiquidateLoan(candy, solId);

        assertEq(size.getCredit(solId), 0);

        _selfLiquidateLoan(bob, solId2);

        assertEq(size.getCredit(solId2), 0);
    }
}
