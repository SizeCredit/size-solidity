// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";

import {BaseTest} from "@test/BaseTest.sol";
import {BaseTestVariablePool} from "@test/BaseTestVariablePool.sol";
import {ForkTest} from "@test/fork/ForkTest.sol";

import {DeployScript} from "@script/Deploy.s.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {SellCreditMarketParams} from "@src/libraries/actions/SellCreditMarket.sol";
import {Test} from "forge-std/Test.sol";

contract DeployScriptTest is ForkTest, BaseTestVariablePool {
    DeployScript deployScript;

    function setUp() public override(ForkTest, BaseTest) {
        super.setUp();
    }

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
        assertEq(size.getUserView(alice).borrowATokenBalance, usdcAmount);
    }

    function testFork_Deploy_deposit_withdraw() public {
        uint256 usdcAmount = 3.1415e6;
        _deposit(alice, usdc, usdcAmount);

        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(variablePool)), usdcAmount);
        assertEq(size.getUserView(alice).borrowATokenBalance, usdcAmount);

        _withdraw(alice, usdc, usdcAmount);

        assertEq(usdc.balanceOf(alice), usdcAmount);
        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(variablePool)), 0);
        assertEq(size.getUserView(alice).borrowATokenBalance, 0);
    }

    function testFork_Deploy_deposit_buyCreditLimit_borrow() public {
        _deposit(alice, usdc, 2500 * 1e6);
        _buyCreditLimit(
            alice, block.timestamp + 365 days, [int256(0.05e18), int256(0.07e18)], [uint256(30 days), uint256(180 days)]
        );

        vm.warp(block.timestamp + 30 days);

        _deposit(bob, weth, 1e18);
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 1_000e6, 60 days, false);

        assertEq(debtPositionId, 0);
        assertEq(size.getUserView(alice).borrowATokenBalance, 1_500e6);
        assertEq(size.getUserView(bob).borrowATokenBalance, 1_000e6);
    }

    function testFork_Deploy_RevertWith_depositVariable_borrowVariable_low_liquidity() public {
        _depositVariable(alice, usdc, 2_500e6);
        _depositVariable(candy, weth, 2e18);
        _borrowVariable(candy, 2_000e6);
        assertEq(aToken.balanceOf(alice), 2_500e6);
        assertEq(aToken.scaledBalanceOf(alice), 2_500e6);

        vm.expectRevert();
        _withdrawVariable(alice, usdc, 2_500e6);
    }

    function testFork_Deploy_RevertWith_deposit_buyCreditLimit_variablePool_borrow_borrow_low_liquidity() public {
        _deposit(alice, usdc, 2_500e6);
        assertEq(usdc.balanceOf(address(variablePool)), 2_500e6);
        _buyCreditLimit(
            alice, block.timestamp + 365 days, [int256(0.05e18), int256(0.07e18)], [uint256(30 days), uint256(180 days)]
        );

        vm.warp(block.timestamp + 30 days);

        _depositVariable(candy, weth, 2e18);
        _borrowVariable(candy, 2_000e6);

        assertEq(usdc.balanceOf(address(variablePool)), 500e6);
        assertEq(usdc.balanceOf(candy), 2_000e6);
        assertEq(size.getUserView(alice).borrowATokenBalance, 2_500e6);

        _deposit(bob, weth, 1e18);
        _sellCreditMarket(bob, alice, RESERVED_ID, 1_000e6, 60 days, false);
        vm.expectRevert();
        _withdraw(bob, usdc, 1_000e6);
    }

    function testFork_Deploy_transferBorrowAToken_reverts_if_low_liquidity() public {
        _setPrice(2468e18);
        _deposit(alice, usdc, 2_500e6);
        assertEq(usdc.balanceOf(address(variablePool)), 2_500e6);
        _buyCreditLimit(
            alice, block.timestamp + 365 days, [int256(0.05e18), int256(0.07e18)], [uint256(30 days), uint256(180 days)]
        );

        vm.warp(block.timestamp + 30 days);

        _depositVariable(candy, weth, 2e18);
        _borrowVariable(candy, 2_000e6);

        assertEq(usdc.balanceOf(address(variablePool)), 500e6);
        assertEq(usdc.balanceOf(candy), 2_000e6);
        assertEq(size.getUserView(alice).borrowATokenBalance, 2_500e6);

        _deposit(bob, weth, 1e18);

        uint256 tenor = 60 days;
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.NOT_ENOUGH_BORROW_ATOKEN_LIQUIDITY.selector, 500e6, 2500e6));
        size.sellCreditMarket(
            SellCreditMarketParams({
                lender: alice,
                creditPositionId: RESERVED_ID,
                amount: 1_000e6,
                tenor: tenor,
                deadline: block.timestamp,
                maxAPR: type(uint256).max,
                exactAmountIn: false
            })
        );
    }
}
