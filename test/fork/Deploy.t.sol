// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {BaseTestVariablePool} from "@test/BaseTestVariablePool.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {DeployScript} from "@script/Deploy.s.sol";

import {Test} from "forge-std/Test.sol";

contract DeployScriptTest is ForkTest, BaseTestVariablePool {
    DeployScript deployScript;

    function setUp() public override(ForkTest, BaseTest) {
        super.setUp();
        vm.rollFork(6252509);
    }

    function testFork_Deploy_size_is_configured() public {
        assertTrue(address(size.data().variablePool) != address(0));
        assertTrue(address(size.oracle().priceFeed) != address(0));
        assertTrue(address(size.feeConfig().feeRecipient) != address(0));
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
        assertEq(usdc.balanceOf(address(aToken)), usdcAmount);
        assertEq(size.getUserView(alice).borrowATokenBalance, usdcAmount);
    }

    function testFork_Deploy_deposit_withdraw() public {
        uint256 usdcAmount = 3.1415e6;
        _deposit(alice, usdc, usdcAmount);

        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(aToken)), usdcAmount);
        assertEq(size.getUserView(alice).borrowATokenBalance, usdcAmount);

        _withdraw(alice, usdc, usdcAmount);

        assertEq(usdc.balanceOf(alice), usdcAmount);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(aToken)), 0);
        assertEq(size.getUserView(alice).borrowATokenBalance, 0);
    }
}
