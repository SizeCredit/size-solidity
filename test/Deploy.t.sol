// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {ForkTest} from "@test/ForkTest.sol";

contract DeployScriptTest is ForkTest {
    function testFork_Deploy_size_is_configured() public {
        assertTrue(address(size.data().variablePool) != address(0));
        assertTrue(address(size.oracle().priceFeed) != address(0));
        assertEq(address(size.data().variablePool), address(variablePool));
        assertEq(address(size.oracle().priceFeed), address(priceFeed));
        assertEq(size.data().variablePool.getReserveNormalizedIncome(address(usdc)), WadRayMath.RAY);
        assertTrue(2000e18 < priceFeed.getPrice() && priceFeed.getPrice() < 3000e18);
    }

    function testFork_Deploy_deposit() public {
        uint256 usdcAmount = 1_234 * 1e6;
        _deposit(alice, usdc, usdcAmount);
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(variablePool)), usdcAmount);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, usdcAmount);
    }

    function testFork_Deploy_deposit_withdraw() public {
        uint256 usdcAmount = 3.1415e6;
        _deposit(alice, usdc, usdcAmount);

        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(variablePool)), usdcAmount);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, usdcAmount);

        _withdraw(alice, usdc, usdcAmount);

        assertEq(usdc.balanceOf(alice), usdcAmount);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(variablePool)), 0);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, 0);
    }

    function testFork_Deploy_deposit_lendAsLimitOrder_borrowAsMarketOrder() public {
        _deposit(alice, usdc, 2500 * 1e6);
        _lendAsLimitOrder(
            alice, block.timestamp + 365 days, [int256(0.05e18), int256(0.07e18)], [uint256(30 days), uint256(180 days)]
        );

        vm.warp(block.timestamp + 30 days);

        _deposit(bob, weth, 1e18);
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 1_000e6, block.timestamp + 60 days);

        assertEq(debtPositionId, 0);
        assertEq(size.getDebtPosition(debtPositionId).issuanceValue, 1_000e6);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, 1_500e6);
        assertEq(size.getUserView(bob).borrowATokenBalanceFixed, 1_000e6);
    }

    function testFork_Deploy_RevertWith_depositVariable_borrowVariable_low_liquidity() public {
        _depositVariable(alice, usdc, 2_500e6);
        _depositVariable(candy, weth, 2e18);
        _borrowVariable(candy, usdc, 2_000e6);
        assertEq(aToken.balanceOf(alice), 2_500e6);
        assertEq(aToken.scaledBalanceOf(alice), 2_500e6);

        vm.expectRevert();
        _withdrawVariable(alice, usdc, 2_500e6);
    }

    function testFork_Deploy_RevertWith_deposit_lendAsLimitOrder_variablePool_borrow_borrowAsMarketOrder_low_liquidity()
        public
    {
        _deposit(alice, usdc, 2_500e6);
        assertEq(usdc.balanceOf(address(variablePool)), 2_500e6);
        _lendAsLimitOrder(
            alice, block.timestamp + 365 days, [int256(0.05e18), int256(0.07e18)], [uint256(30 days), uint256(180 days)]
        );

        vm.warp(block.timestamp + 30 days);

        _depositVariable(candy, weth, 2e18);
        _borrowVariable(candy, usdc, 2_000e6);

        assertEq(usdc.balanceOf(address(variablePool)), 500e6);
        assertEq(usdc.balanceOf(candy), 2_000e6);
        assertEq(size.getUserView(alice).borrowATokenBalanceFixed, 2_500e6);
        assertEq(aToken.balanceOf(address(size.getUserView(alice).user.vaultFixed)), 2_500e6);
        assertEq(aToken.scaledBalanceOf(address(size.getUserView(alice).user.vaultFixed)), 2_500e6);

        _deposit(bob, weth, 1e18);
        _borrowAsMarketOrder(bob, alice, 1_000e6, block.timestamp + 60 days);
        vm.expectRevert();
        _withdraw(bob, usdc, 1_000e6);
    }
}
