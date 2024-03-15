// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {VariableDebtToken} from "@aave/protocol/tokenization/VariableDebtToken.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract BorrowVariableTest is BaseTest {
    function test_BorrowVariable_borrowVariable() public {
        _depositVariable(alice, weth, 1e18);
        _depositVariable(bob, usdc, 100e6);
        _borrowVariable(alice, 100e6);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, 0);
        assertEq(size.getUserView(alice).borrowATokenBalanceVariable, 100e6);
        assertEq(size.getUserView(alice).debtBalanceFixed, 0);
        assertEq(size.data().debtToken.totalSupply(), 0);
        assertEq(
            VariableDebtToken(variablePool.getReserveData(address(usdc)).variableDebtTokenAddress).balanceOf(
                address(size.getUserView(alice).user.vaultVariable)
            ),
            100e6
        );
        assertEq(
            VariableDebtToken(variablePool.getReserveData(address(usdc)).variableDebtTokenAddress).totalSupply(), 100e6
        );
    }
}
