// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {console} from "forge-std/console.sol";

import {BaseTest} from "@test/BaseTest.sol";

import {UserView} from "@src/SizeView.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/MathLibrary.sol";
import {DepositVariableParams} from "@src/libraries/variable/actions/DepositVariable.sol";
import {WithdrawVariableParams} from "@src/libraries/variable/actions/WithdrawVariable.sol";

contract WithdrawVariableTest is BaseTest {
    function test_WithdrawVariable_withdrawVariable_decreases_user_balance() public {
        _depositVariable(alice, address(usdc), 12e6);
        _depositVariable(alice, address(weth), 23e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.variableBorrowAmount, 12e18);
        assertEq(aliceUser.variableCollateralAmount, 23e18);

        _withdrawVariable(alice, address(usdc), 9e6);
        _withdrawVariable(alice, address(weth), 7e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.variableBorrowAmount, 3e18);
        assertEq(aliceUser.variableCollateralAmount, 16e18);
    }

    function test_WithdrawVariable_withdrawVariable_decreases_user_balance_time() public {
        _depositVariable(alice, address(usdc), 12e6);
        _depositVariable(alice, address(weth), 23e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.variableBorrowAmount, 12e18);
        assertEq(aliceUser.variableCollateralAmount, 23e18);

        vm.warp(block.timestamp + 1 days);

        _withdrawVariable(alice, address(usdc), 9e6);
        _withdrawVariable(alice, address(weth), 7e18);
        aliceUser = size.getUserView(alice);
        assertGt(aliceUser.variableBorrowAmount, 3e18);
        assertEq(aliceUser.variableCollateralAmount, 16e18);
    }

    function testFuzz_WithdrawVariable_withdrawVariable_decreases_user_balance(
        uint256 x,
        uint256 y,
        uint256 z,
        uint256 w
    ) public {
        x = bound(x, 1, type(uint96).max);
        y = bound(y, 1, type(uint96).max);
        z = bound(z, 1, type(uint96).max);
        w = bound(w, 1, type(uint96).max);

        _depositVariable(alice, address(usdc), x * 1e6);
        _depositVariable(alice, address(weth), y * 1e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.variableBorrowAmount, x * 1e18);
        assertEq(aliceUser.variableCollateralAmount, y * 1e18);

        z = bound(z, 1, x);
        w = bound(w, 1, y);

        _withdrawVariable(alice, address(usdc), z * 1e6);
        _withdrawVariable(alice, address(weth), w * 1e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.variableBorrowAmount, (x - z) * 1e18);
        assertEq(aliceUser.variableCollateralAmount, (y - w) * 1e18);
    }

    function testFuzz_WithdrawVariable_withdrawVariable_decreases_user_balance_time(
        uint256 x,
        uint256 y,
        uint256 z,
        uint256 w,
        uint256 interval
    ) public {
        x = bound(x, 1, type(uint96).max);
        y = bound(y, 1, type(uint96).max);
        z = bound(z, 1, type(uint96).max);
        w = bound(w, 1, type(uint96).max);
        interval = bound(interval, 1, 6 * 365 days);

        _depositVariable(alice, address(usdc), x * 1e6);
        _depositVariable(alice, address(weth), y * 1e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.variableBorrowAmount, x * 1e18);
        assertEq(aliceUser.variableCollateralAmount, y * 1e18);

        z = bound(z, 1, x);
        w = bound(w, 1, y);
        vm.warp(block.timestamp + interval);

        _withdrawVariable(alice, address(usdc), z * 1e6);
        _withdrawVariable(alice, address(weth), w * 1e18);
        aliceUser = size.getUserView(alice);
        assertGt(aliceUser.variableBorrowAmount, (x - z) * 1e18);
        assertEq(aliceUser.variableCollateralAmount, (y - w) * 1e18);
    }

    function testFuzz_WithdrawVariable_depositVariable_withdrawVariable_identity(uint256 valueUSDC, uint256 valueWETH)
        public
    {
        valueUSDC = bound(valueUSDC, 1, type(uint96).max);
        valueWETH = bound(valueWETH, 1, type(uint96).max);
        deal(address(usdc), alice, valueUSDC);
        deal(address(weth), alice, valueWETH);

        vm.startPrank(alice);
        IERC20Metadata(usdc).approve(address(size), valueUSDC);
        IERC20Metadata(weth).approve(address(size), valueWETH);

        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(alice)), valueWETH);

        size.depositVariable(DepositVariableParams({token: address(usdc), amount: valueUSDC}));
        size.depositVariable(DepositVariableParams({token: address(weth), amount: valueWETH}));

        assertEq(usdc.balanceOf(address(size)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), valueWETH);

        size.withdrawVariable(WithdrawVariableParams({token: address(usdc), amount: valueUSDC}));
        size.withdrawVariable(WithdrawVariableParams({token: address(weth), amount: valueWETH}));

        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), 0);
        assertEq(weth.balanceOf(address(alice)), valueWETH);
    }

    function testFuzz_WithdrawVariable_depositVariable_withdrawVariable_identity_time(
        uint256 valueUSDC,
        uint256 valueWETH,
        uint256 interval
    ) public {
        valueUSDC = bound(valueUSDC, 1, type(uint96).max);
        valueWETH = bound(valueWETH, 1, type(uint96).max);
        interval = bound(interval, 1, 6 * 365 days);
        deal(address(usdc), alice, valueUSDC);
        deal(address(weth), alice, valueWETH);

        vm.startPrank(alice);
        IERC20Metadata(usdc).approve(address(size), valueUSDC);
        IERC20Metadata(weth).approve(address(size), valueWETH);

        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(alice)), valueWETH);

        size.depositVariable(DepositVariableParams({token: address(usdc), amount: valueUSDC}));
        size.depositVariable(DepositVariableParams({token: address(weth), amount: valueWETH}));

        assertEq(usdc.balanceOf(address(size)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), valueWETH);
        assertEq(size.getUserView(alice).variableBorrowAmount, valueUSDC * 1e12);
        assertEq(size.getUserView(alice).variableCollateralAmount, valueWETH);

        vm.warp(block.timestamp + interval);
        assertGt(size.getUserView(alice).variableBorrowAmount, valueUSDC * 1e12);
        assertEq(size.getUserView(alice).variableCollateralAmount, valueWETH);

        size.withdrawVariable(WithdrawVariableParams({token: address(usdc), amount: valueUSDC}));
        size.withdrawVariable(WithdrawVariableParams({token: address(weth), amount: valueWETH}));
        assertGt(size.getUserView(alice).variableBorrowAmount, 0);
        assertEq(size.getUserView(alice).variableCollateralAmount, 0);

        assertEq(usdc.balanceOf(address(size)), 0);
        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), 0);
        assertEq(weth.balanceOf(address(alice)), valueWETH);
    }

    function test_WithdrawVariable_user_cannot_withdrawVariable_if_that_would_leave_them_underwater() internal {
        // TODO
        // _setPrice(1e18);
        // _depositVariable(alice, usdc, 100e6);
        // _depositVariable(bob, weth, 150e18);
        // _lendAsLimitOrder(alice, 100e18, 12, 0, 12);
        // _borrowAsMarketOrder(bob, alice, 100e18, 12);

        // vm.startPrank(bob);
        // vm.expectRevert(abi.encodeWithSelector(Errors.USER_IS_LIQUIDATABLE.selector, bob, 0));
        // size.withdrawVariable(WithdrawVariableParams({token: address(weth), amount: 150e18}));

        // vm.startPrank(bob);
        // vm.expectRevert(abi.encodeWithSelector(Errors.USER_IS_LIQUIDATABLE.selector, bob, 0.01e18));
        // size.withdrawVariable(WithdrawVariableParams({token: address(weth), amount: 149e18}));
    }

    function test_WithdrawVariable_withdrawVariable_everything() internal {
        // TODO
        // _setPrice(1e18);
        // _depositVariable(alice, usdc, 100e6);
        // _depositVariable(bob, weth, 150e18);

        // uint256 beforeUSDC = usdc.balanceOf(address(alice));
        // uint256 beforeWETH = weth.balanceOf(address(bob));

        // _withdrawVariable(alice, usdc, type(uint256).max);
        // _withdrawVariable(bob, weth, type(uint256).max);

        // uint256 afterUSDC = usdc.balanceOf(address(alice));
        // uint256 afterWETH = weth.balanceOf(address(bob));

        // assertEq(beforeUSDC, 0);
        // assertEq(beforeWETH, 0);
        // assertEq(afterUSDC, 100e6);
        // assertEq(afterWETH, 150e18);
    }

    function test_WithdrawVariable_withdrawVariable_everything_may_leave_dust_due_to_wad_conversion() internal {
        // TODO
        // _setPrice(1e18);
        // uint256 liquidatorAmount = 10_000e6;
        // _depositVariable(alice, usdc, 100e6);
        // _depositVariable(bob, weth, 150e18);
        // _depositVariable(liquidator, usdc, 10_000e6);
        // uint256 rate = 1;
        // _lendAsLimitOrder(alice, 100e18, 12, rate, 12);
        // uint256 amount = 15e18;
        // uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        // uint256 debt = Math.mulDivUp(amount, (PERCENT + rate), PERCENT);
        // uint256 debtUSDC = Math.mulDivUp(debt, 1e6, 1e18);
        // uint256 dust = ConversionLibrary.amountToWad(debtUSDC, usdc.decimals()) - debt;

        // _setPrice(0.125e18);

        // _liquidateFixedLoan(liquidator, loanId);
        // _withdrawVariable(liquidator, usdc, type(uint256).max);

        // uint256 a = usdc.balanceOf(liquidator);
        // assertEq(a, liquidatorAmount - debtUSDC);
        // assertEq(_state().liquidator.variableBorrowAmount, dust);
        // assertGt(_state().liquidator.variableBorrowAmount, 0);
    }
}
