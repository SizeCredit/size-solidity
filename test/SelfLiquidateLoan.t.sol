// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";

import {BaseTest} from "./BaseTest.sol";

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {PERCENT} from "@src/libraries/MathLibrary.sol";
import {User} from "@src/libraries/UserLibrary.sol";

contract SelfLiquidateLoanTest is BaseTest {
    function test_SelfLiquidateLoan_selfliquidateLoan_rapays_with_collateral() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);

        assertEq(size.collateralRatio(bob), type(uint256).max);

        _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        uint256 loanId = _borrowAsMarketOrder(bob, alice, 100e18, 12);

        assertEq(size.getAssignedCollateral(loanId), 150e18);
        assertEq(size.getDebt(loanId), 100e18);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isLiquidatable(bob));
        assertTrue(!size.isLiquidatable(loanId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        vm.expectRevert();
        _liquidateLoan(liquidator, loanId);

        Vars memory _before = _state();

        _selfLiquidateLoan(bob, loanId);

        Vars memory _after = _state();

        assertEq(_after.bob.collateralAmount, _before.bob.collateralAmount - 150e18, 0);
        assertEq(_after.alice.collateralAmount, _before.alice.collateralAmount + 150e18);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - 100e18);
    }

    function test_SelfLiquidateLoan_selfliquidateLoan_SOL_keeps_accounting_in_check() public {
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
        _borrowAsMarketOrder(alice, james, 100e18, 12, [folId]);

        assertEq(size.getAssignedCollateral(folId), 150e18);
        assertEq(size.getDebt(folId), 100e18);
        assertEq(size.collateralRatio(bob), 1.5e18);
        assertTrue(!size.isLiquidatable(bob));
        assertTrue(!size.isLiquidatable(folId));

        _setPrice(0.5e18);
        assertEq(size.collateralRatio(bob), 0.75e18);

        vm.expectRevert();
        _liquidateLoan(liquidator, folId);

        Vars memory _before = _state();

        _selfLiquidateLoan(alice, solId);

        Vars memory _after = _state();

        assertEq(_after.alice.collateralAmount, _before.alice.collateralAmount - 150e18, 0);
        assertEq(_after.candy.collateralAmount, _before.candy.collateralAmount + 150e18);
        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - 100e18);
    }
}
