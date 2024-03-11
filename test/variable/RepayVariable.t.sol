// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

contract RepayVariableTest is BaseTest {
    function test_RepayVariable_borrowVariable_repayVariable() public {
        _depositVariable(alice, weth, 1e18);
        _depositVariable(bob, usdc, 100e6);
        _borrowVariable(alice, 100e6);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, 0);
        assertEq(size.getUserView(alice).borrowATokenBalanceVariable, 100e6);
        assertEq(size.getUserView(alice).debtBalanceVariable, 100e6);
        _setLiquidityIndex(2e27);
        assertEq(size.getUserView(alice).debtBalanceVariable, 200e6);
        _repayVariable(alice, 200e6);
    }
}
