// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BaseTest} from "@test/BaseTest.sol";

import {UserView} from "@src/SizeView.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {DepositParams} from "@src/libraries/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/actions/Withdraw.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract WithdrawTest is BaseTest {
    function test_Withdraw_withdraw_decreases_user_balance() public {
        _deposit(alice, usdc, 12e6);
        _deposit(alice, weth, 23e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, 12e6);
        assertEq(aliceUser.collateralTokenBalance, 23e18);

        _withdraw(alice, usdc, 9e6);
        _withdraw(alice, weth, 7e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, 3e6);
        assertEq(aliceUser.collateralTokenBalance, 16e18);
    }

    function testFuzz_Withdraw_withdraw_decreases_user_balance(uint256 x, uint256 y, uint256 z, uint256 w) public {
        _updateConfig("borrowATokenCap", type(uint256).max);

        x = bound(x, 1, type(uint96).max);
        y = bound(y, 1, type(uint96).max);
        z = bound(z, 1, type(uint128).max);
        w = bound(w, 1, type(uint128).max);

        _deposit(alice, usdc, x * 1e6);
        _deposit(alice, weth, y * 1e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, x * 1e6);
        assertEq(aliceUser.collateralTokenBalance, y * 1e18);

        z = bound(z, 1, x);
        w = bound(w, 1, y);

        _withdraw(alice, usdc, z * 1e6);
        _withdraw(alice, weth, w * 1e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowATokenBalance, (x - z) * 1e6);
        assertEq(aliceUser.collateralTokenBalance, (y - w) * 1e18);
    }

    function testFuzz_Withdraw_deposit_withdraw_identity(uint256 valueUSDC, uint256 valueWETH) public {
        _updateConfig("borrowATokenCap", type(uint256).max);

        valueUSDC = bound(valueUSDC, 1, type(uint96).max);
        valueWETH = bound(valueWETH, 1, type(uint256).max);
        deal(address(usdc), alice, valueUSDC);
        deal(address(weth), alice, valueWETH);

        vm.startPrank(alice);
        IERC20Metadata(usdc).approve(address(size), valueUSDC);
        IERC20Metadata(weth).approve(address(size), valueWETH);

        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(alice)), valueWETH);

        size.deposit(DepositParams({token: address(usdc), amount: valueUSDC, to: alice}));
        size.deposit(DepositParams({token: address(weth), amount: valueWETH, to: alice}));

        assertEq(usdc.balanceOf(address(variablePool)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), valueWETH);

        size.withdraw(WithdrawParams({token: address(usdc), amount: valueUSDC, to: bob}));
        size.withdraw(WithdrawParams({token: address(weth), amount: valueWETH, to: bob}));

        assertEq(usdc.balanceOf(address(variablePool)), 0);
        assertEq(usdc.balanceOf(address(bob)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), 0);
        assertEq(weth.balanceOf(address(bob)), valueWETH);
    }

    function testFuzz_Withdraw_deposit_withdraw_setLiquidityIndex_identity(
        uint256 valueUSDC,
        uint256 valueWETH,
        uint256 index
    ) public {
        _updateConfig("borrowATokenCap", type(uint256).max);
        index = bound(index, WadRayMath.RAY, WadRayMath.RAY * 2);
        _setLiquidityIndex(index);

        valueUSDC = bound(valueUSDC, 1, type(uint96).max);
        valueWETH = bound(valueWETH, 1, type(uint256).max);
        deal(address(usdc), alice, valueUSDC);
        deal(address(weth), alice, valueWETH);

        vm.startPrank(alice);
        IERC20Metadata(usdc).approve(address(size), valueUSDC);
        IERC20Metadata(weth).approve(address(size), valueWETH);

        assertEq(usdc.balanceOf(address(alice)), valueUSDC);
        assertEq(weth.balanceOf(address(alice)), valueWETH);

        size.deposit(DepositParams({token: address(usdc), amount: valueUSDC, to: alice}));
        size.deposit(DepositParams({token: address(weth), amount: valueWETH, to: alice}));

        assertEq(usdc.balanceOf(address(variablePool)), valueUSDC);
        assertEq(weth.balanceOf(address(size)), valueWETH);

        size.withdraw(WithdrawParams({token: address(usdc), amount: valueUSDC, to: bob}));
        size.withdraw(WithdrawParams({token: address(weth), amount: valueWETH, to: bob}));

        assertEqApprox(usdc.balanceOf(address(variablePool)), 0, 1);
        assertEqApprox(usdc.balanceOf(address(bob)), valueUSDC, 1);
        assertEq(weth.balanceOf(address(size)), 0);
        assertEq(weth.balanceOf(address(bob)), valueWETH);
    }

    function test_Withdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 150e18);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _sellCreditMarket(bob, alice, RESERVED_ID, 50e6, 12 days, false);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, bob, 0, 1.5e18));
        size.withdraw(WithdrawParams({token: address(weth), amount: 150e18, to: bob}));
    }

    function test_Withdraw_withdraw_everything_general() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);

        uint256 beforeUSDC = usdc.balanceOf(address(alice));
        uint256 beforeWETH = weth.balanceOf(address(bob));

        _withdraw(alice, usdc, type(uint256).max);
        _withdraw(bob, weth, type(uint256).max);

        uint256 afterUSDC = usdc.balanceOf(address(alice));
        uint256 afterWETH = weth.balanceOf(address(bob));

        assertEq(beforeUSDC, 0);
        assertEq(beforeWETH, 0);
        assertEq(afterUSDC, 100e6);
        assertEq(afterWETH, 150e18);
    }

    function test_Withdraw_withdraw_everything_without_deposit_general() public {
        uint256 beforeUSDC = usdc.balanceOf(address(alice));
        uint256 beforeWETH = weth.balanceOf(address(alice));

        assertEq(beforeUSDC, 0);
        assertEq(beforeWETH, 0);

        _withdraw(alice, usdc, type(uint256).max);
        assertEq(usdc.balanceOf(address(alice)), beforeUSDC);
        assertEq(weth.balanceOf(address(alice)), beforeWETH);

        _withdraw(alice, weth, type(uint256).max);
        assertEq(usdc.balanceOf(address(alice)), beforeUSDC);
        assertEq(weth.balanceOf(address(alice)), beforeWETH);

        _withdraw(alice, usdc, 1);
        assertEq(usdc.balanceOf(address(alice)), beforeUSDC);
        assertEq(weth.balanceOf(address(alice)), beforeWETH);

        _withdraw(alice, weth, 1);
        assertEq(usdc.balanceOf(address(alice)), beforeUSDC);
        assertEq(weth.balanceOf(address(alice)), beforeWETH);

        assertEq(usdc.balanceOf(address(alice)), 0);
        assertEq(weth.balanceOf(address(alice)), 0);
    }

    function test_Withdraw_withdraw_everything_does_not_leave_dust() public {
        _setPrice(1e18);
        uint256 liquidatorAmount = 10_000e6;
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);
        uint256 rate = 1;
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, int256(rate)));
        uint256 amount = 15e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        _setPrice(0.125e18);

        _liquidate(liquidator, debtPositionId);
        _withdraw(liquidator, usdc, type(uint256).max);

        assertEq(usdc.balanceOf(liquidator), liquidatorAmount - futureValue);
        assertEq(_state().variablePool.borrowATokenBalance, 0);
        assertGt(_state().feeRecipient.collateralTokenBalance, 0);
    }

    function test_Withdraw_withdraw_can_leave_borrow_tokens_lower_than_debt_tokens_in_case_of_self_borrow() public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(alice, weth, 160e18);
        _sellCreditLimit(alice, 1e18, 12 days);
        _buyCreditMarket(alice, alice, 100e6, 12 days);
        _withdraw(alice, usdc, 10e6);
        assertLt(size.data().borrowAToken.totalSupply(), size.data().debtToken.totalSupply());
    }

    function test_Withdraw_withdraw_can_leave_borrow_tokens_lower_than_debt_tokens_in_case_of_borrow_followed_by_withdraw(
    ) public {
        _setPrice(1e18);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _sellCreditLimit(bob, 1e18, 12 days);
        _buyCreditMarket(alice, bob, 100e6, 12 days);
        _withdraw(bob, usdc, 10e6);
        assertLt(size.data().borrowAToken.totalSupply(), size.data().debtToken.totalSupply());
    }

    function testFuzz_Withdraw_withdraw_more_than_balance(uint256 index, uint256 delta) public {
        index = bound(index, 1e27, 2e27);
        delta = bound(delta, 0, 1e6);
        _setPrice(1e18);
        _deposit(bob, usdc, 1_000e6);
        _setLiquidityIndex(index);
        _deposit(alice, usdc, 100e6);
        _withdraw(alice, usdc, 100e6 + delta);
        assertTrue(usdc.balanceOf(address(alice)) == 100e6 || usdc.balanceOf(address(alice)) == 100e6 - 1);
    }
}
