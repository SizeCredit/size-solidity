// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

contract LiquidateVariableTest is BaseTest {
    function test_LiquidateVariable_borrowVariable_liquidateVariable() public {
        _setPrice(1e18);
        _depositVariable(alice, weth, 200e18);
        _depositVariable(bob, usdc, 100e6);
        _depositVariable(liquidator, usdc, 100e6);
        _borrowVariable(alice, 50e6);
        _setPrice(0.5e18);
        _liquidateVariable(liquidator, alice, 50e6);
        Vars memory vars = _state();
        assertEq(vars.liquidator.collateralATokenBalanceVariable, 100e18);
        assertEq(vars.alice.debtBalanceVariable, 0);
    }
}
