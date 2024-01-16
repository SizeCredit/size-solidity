// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest} from "./BaseTest.sol";
import {Vars} from "./BaseTestGeneric.sol";

contract SelfLiquidateFixedLoanTest is BaseTest {
    function test_SelfLiquidateFixedLoan_selfliquidateFixedLoan_rapays_with_collateral() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        assertEq(size.getFOLAssignedCollateral(loanId), 150e18);
        assertEq(size.getDebt(loanId), 100e18);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isLiquidatable(bob));
        assertTrue(!size.isLiquidatable(loanId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        vm.expectRevert();
        _liquidateFixedLoan(liquidator, loanId);

        Vars memory _before = _state();

        _selfLiquidateFixedLoan(alice, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - 150e18, 0);
        assertEq(_after.alice.collateralAmount, _before.alice.collateralAmount + 150e18);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - 100e18);
    }

    function test_SelfLiquidateFixedLoan_selfliquidateFixedLoan_SOL_keeps_accounting_in_check() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 100e6);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 100e18, 12, 0, 12);
        uint256 folId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 100e18, 12, [folId]);
        _borrowAsMarketOrder(alice, james, 100e18, 12);

        assertEq(size.getFOLAssignedCollateral(folId), 150e18);
        assertEq(size.getDebt(folId), 100e18);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isLiquidatable(bob));
        assertTrue(!size.isLiquidatable(folId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        vm.expectRevert();
        _liquidateFixedLoan(liquidator, folId);

        Vars memory _before = _state();

        _selfLiquidateFixedLoan(candy, solId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - 150e18, 0);
        assertEq(_after.candy.collateralAmount, _before.candy.collateralAmount + 150e18);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - 100e18);
    }

    function test_SelfLiquidateFixedLoan_selfliquidateFixedLoan_FOL_should_not_leave_dust_loan_when_no_exits() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        _setPrice(0.0001e18);
        _selfLiquidateFixedLoan(alice, loanId);
    }

    function test_SelfLiquidateFixedLoan_selfliquidateFixedLoan_FOL_should_not_leave_dust_loan_when_exits() public {
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
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 200e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 50e18, 12);
        _borrowAsMarketOrder(alice, candy, 5e18, 12, [loanId]);
        _borrowAsMarketOrder(alice, james, 80e18, 12);
        _borrowAsMarketOrder(bob, james, 40e18, 12);

        _setPrice(0.25e18);

        assertEq(size.getFixedLoan(loanId).faceValue, 50e18);
        assertEq(size.getFixedLoan(loanId).faceValueExited, 5e18);
        assertEq(size.getCredit(loanId), 45e18);

        _selfLiquidateFixedLoan(alice, loanId);

        assertEq(size.getFixedLoan(loanId).faceValue, 5e18);
        assertEq(size.getFixedLoan(loanId).faceValueExited, 5e18);
        assertEq(size.getCredit(loanId), 0);
    }

    function test_SelfLiquidateFixedLoan_selfliquidateFixedLoan_SOL_should_not_leave_dust_loan() public {
        _setPrice(1e18);

        _deposit(alice, weth, 150e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 300e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 150e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, usdc, 200e6);
        _deposit(liquidator, usdc, 10_000e6);
        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        _lendAsLimitOrder(bob, 100e18, 12, 0, 12);
        _lendAsLimitOrder(candy, 100e18, 12, 0, 12);
        _lendAsLimitOrder(james, 200e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);
        uint256 solId = _borrowAsMarketOrder(alice, candy, 49e18, 12, [loanId]);
        uint256 solId2 = _borrowAsMarketOrder(candy, bob, 44e18, 12, [solId]);
        _borrowAsMarketOrder(alice, james, 60e18, 12);
        _borrowAsMarketOrder(candy, james, 80e18, 12);

        _setPrice(0.25e18);

        _selfLiquidateFixedLoan(candy, solId);

        assertEq(size.getCredit(solId), 0);

        _selfLiquidateFixedLoan(bob, solId2);

        assertEq(size.getCredit(solId2), 0);
    }
}
