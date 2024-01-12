// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {BaseTest, Vars} from "./BaseTest.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Math, PERCENT} from "@src/libraries/MathLibrary.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/actions/LendAsLimitOrder.sol";
import {LiquidateFixedLoanParams} from "@src/libraries/actions/LiquidateFixedLoan.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract MulticallTest is BaseTest {
    function test_Multicall_multicall_can_deposit_and_create_loanOffer() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        assertEq(size.getUserView(alice).borrowAmount, 0);
        assertEq(size.getUserView(alice).user.loanOffer.maxAmount, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount})));
        data[1] = abi.encodeCall(
            size.lendAsLimitOrder,
            LendAsLimitOrderParams({
                maxAmount: amount * 1e12 / 2,
                maxDueDate: block.timestamp + 1 days,
                curveRelativeTime: YieldCurveHelper.flatCurve()
            })
        );
        size.multicall(data);

        assertEq(size.getUserView(alice).borrowAmount, amount * 1e12, "x");
        assertEq(size.getUserView(alice).user.loanOffer.maxAmount, amount * 1e12 / 2, "a");
    }

    function test_Multicall_multicall_cannot_execute_unauthorized_actions() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount})));
        data[1] = abi.encodeCall(size.transferOwnership, (alice));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        size.multicall(data);
    }

    function test_Multicall_liquiadtor_can_liquidate_and_withdraw() public {
        _setPrice(1e18);

        _deposit(alice, 100e18, 100e18);
        _deposit(bob, 100e18, 100e18);

        _lendAsLimitOrder(alice, 100e18, 12, 0.03e18, 12);
        uint256 amount = 15e18;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 debt = Math.mulDivUp(amount, (PERCENT + 0.03e18), PERCENT);

        _setPrice(0.2e18);

        assertTrue(size.isLiquidatable(loanId));

        uint256 debtUSDC = Math.mulDivUp(debt, 1e6, 1e18);
        _mint(address(usdc), liquidator, debtUSDC);
        _approve(liquidator, address(usdc), address(size), debtUSDC);

        Vars memory _before = _state();
        uint256 beforeLiquidatorUSDC = usdc.balanceOf(liquidator);
        uint256 beforeLiquidatorWETH = weth.balanceOf(liquidator);

        bytes[] memory data = new bytes[](4);
        // deposit only the necessary to cover for the borrower's debt
        data[0] = abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: debtUSDC}));
        // liquidate profitably
        data[1] = abi.encodeCall(
            size.liquidateFixedLoan, LiquidateFixedLoanParams({loanId: loanId, minimumCollateralRatio: 1e18})
        );
        // withdraw everything
        data[2] = abi.encodeCall(size.withdraw, WithdrawParams({token: address(weth), amount: type(uint256).max}));
        data[3] = abi.encodeCall(size.withdraw, WithdrawParams({token: address(usdc), amount: type(uint256).max}));
        vm.prank(liquidator);
        size.multicall(data);

        Vars memory _after = _state();
        uint256 afterLiquidatorUSDC = usdc.balanceOf(liquidator);
        uint256 afterLiquidatorWETH = weth.balanceOf(liquidator);

        assertEq(_after.bob.debtAmount, _before.bob.debtAmount - debt, 0);
        assertEq(_after.liquidator.borrowAmount, _before.liquidator.borrowAmount, 0);
        assertEq(_after.liquidator.collateralAmount, _before.liquidator.collateralAmount, 0);
        assertEq(beforeLiquidatorWETH, 0);
        assertGt(afterLiquidatorWETH, beforeLiquidatorWETH);
        assertEq(beforeLiquidatorUSDC, debtUSDC);
        assertEq(afterLiquidatorUSDC, 0);
    }
}
