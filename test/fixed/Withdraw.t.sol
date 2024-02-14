// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {BaseTest} from "@test/BaseTest.sol";

import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {UserView} from "@src/SizeView.sol";
import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

contract WithdrawTest is BaseTest {
    function test_Withdraw_withdraw_decreases_user_balance() public {
        _deposit(alice, address(usdc), 12e6);
        _deposit(alice, address(weth), 23e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, 12e6);
        assertEq(aliceUser.collateralAmount, 23e18);

        _withdraw(alice, address(usdc), 9e6);
        _withdraw(alice, address(weth), 7e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, 3e6);
        assertEq(aliceUser.collateralAmount, 16e18);
    }

    function testFuzz_Withdraw_withdraw_decreases_user_balance(uint256 x, uint256 y, uint256 z, uint256 w) public {
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);

        x = bound(x, 1, type(uint96).max);
        y = bound(y, 1, type(uint96).max);
        z = bound(z, 1, type(uint128).max);
        w = bound(w, 1, type(uint128).max);

        _deposit(alice, address(usdc), x * 1e6);
        _deposit(alice, address(weth), y * 1e18);
        UserView memory aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, x * 1e6);
        assertEq(aliceUser.collateralAmount, y * 1e18);

        z = bound(z, 1, x);
        w = bound(w, 1, y);

        _withdraw(alice, address(usdc), z * 1e6);
        _withdraw(alice, address(weth), w * 1e18);
        aliceUser = size.getUserView(alice);
        assertEq(aliceUser.borrowAmount, (x - z) * 1e6);
        assertEq(aliceUser.collateralAmount, (y - w) * 1e18);
    }

    function testFuzz_Withdraw_deposit_withdraw_identity(uint256 valueUSDC, uint256 valueWETH) public {
        _updateConfig("collateralTokenCap", type(uint256).max);
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

    function test_Withdraw_user_cannot_withdraw_if_that_would_leave_them_underwater() public {
        _setPrice(1e18);
        _updateConfig("repayFeeAPR", 0);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _lendAsLimitOrder(alice, 12, 0, 12);
        _borrowAsMarketOrder(bob, alice, 100e6, 12);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, bob, 0, 1.5e18));
        size.withdraw(WithdrawParams({token: address(weth), amount: 150e18, to: bob}));

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.CR_BELOW_OPENING_LIMIT_BORROW_CR.selector, bob, 0.01e18, 1.5e18));
        size.withdraw(WithdrawParams({token: address(weth), amount: 149e18, to: bob}));
    }

    function test_Withdraw_withdraw_everythingeneralConfig() public {
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

    function test_Withdraw_withdraw_everything_without_depositingeneralConfig() public {
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

    function test_Withdraw_withdraw_everything_does_not_leave_dust_in_vp_due_to_wad_conversion() public {
        _setPrice(1e18);
        uint256 liquidatorAmount = 10_000e6;
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);
        _deposit(liquidator, usdc, 10_000e6);
        uint256 rate = 1;
        _lendAsLimitOrder(alice, 12, rate, 12);
        uint256 amount = 15e6;
        uint256 loanId = _borrowAsMarketOrder(bob, alice, amount, 12);
        uint256 faceValue = Math.mulDivUp(amount, (PERCENT + rate), PERCENT);

        _setPrice(0.125e18);

        _liquidate(liquidator, loanId);
        _withdraw(liquidator, usdc, type(uint256).max);

        assertEq(usdc.balanceOf(liquidator), liquidatorAmount - faceValue);
        assertEq(_state().variablePool.borrowAmount, 0);
        assertGt(_state().feeRecipient.collateralAmount, 0);
    }

    function test_Withdraw_withdraw_can_leave_borrow_tokens_lower_than_debt_tokens_in_case_of_self_borrow() public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(alice, weth, 160e18);
        _borrowAsLimitOrder(alice, 1e18, 12);
        _lendAsMarketOrder(alice, alice, 100e6, 12);
        _withdraw(alice, usdc, 10e6);
        assertLt(size.data().borrowAToken.totalSupply(), size.data().debtToken.totalSupply());
    }

    function test_Withdraw_withdraw_can_leave_borrow_tokens_lower_than_debt_tokens_in_case_of_borrow_followed_by_withdraw(
    ) public {
        _setPrice(1e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 160e18);
        _borrowAsLimitOrder(bob, 1e18, 12);
        _lendAsMarketOrder(alice, bob, 100e6, 12);
        _withdraw(bob, usdc, 10e6);
        assertLt(size.data().borrowAToken.totalSupply(), size.data().debtToken.totalSupply());
    }
}
