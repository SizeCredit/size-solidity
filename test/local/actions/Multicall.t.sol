// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTest.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DebtPosition} from "@src/market/libraries/LoanLibrary.sol";
import {RepayParams} from "@src/market/libraries/actions/Repay.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {BuyCreditLimitOnBehalfOfParams, BuyCreditLimitParams} from "@src/market/libraries/actions/BuyCreditLimit.sol";

import {DepositOnBehalfOfParams, DepositParams} from "@src/market/libraries/actions/Deposit.sol";

import {LiquidateParams} from "@src/market/libraries/actions/Liquidate.sol";
import {SellCreditLimitParams} from "@src/market/libraries/actions/SellCreditLimit.sol";
import {WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";
import {WithdrawParams} from "@src/market/libraries/actions/Withdraw.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract MulticallTest is BaseTest {
    function test_Multicall_multicall_can_deposit_and_create_loanOffer() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        assertEq(size.getUserView(alice).borrowTokenBalance, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount, to: alice})));
        data[1] = abi.encodeCall(
            size.buyCreditLimit,
            BuyCreditLimitParams({maxDueDate: block.timestamp + 1 days, curveRelativeTime: YieldCurveHelper.flatCurve()})
        );
        bytes[] memory results = size.multicall(data);

        assertEq(results.length, 2);
        assertEq(results[0], bytes(""));
        assertEq(results[1], bytes(""));

        assertEq(size.getUserView(alice).borrowTokenBalance, amount);
    }

    function test_Multicall_multicall_can_deposit_ether_and_create_borrowOffer() public {
        vm.startPrank(alice);
        uint256 amount = 1.23 ether;
        vm.deal(alice, amount);

        assertEq(size.getUserView(alice).collateralTokenBalance, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: address(weth), amount: amount, to: alice})));
        data[1] = abi.encodeCall(
            size.sellCreditLimit,
            SellCreditLimitParams({
                maxDueDate: block.timestamp + 365 days,
                curveRelativeTime: YieldCurveHelper.flatCurve()
            })
        );
        size.multicall{value: amount}(data);

        assertEq(size.getUserView(alice).collateralTokenBalance, amount);
    }

    function test_Multicall_multicall_cannot_credit_more_ether_due_to_payable() public {
        vm.startPrank(alice);
        uint256 amount = 1 wei;
        vm.deal(alice, amount);

        assertEq(size.getUserView(alice).collateralTokenBalance, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: address(weth), amount: amount, to: alice})));
        data[1] = abi.encodeCall(size.deposit, (DepositParams({token: address(weth), amount: amount, to: alice})));
        size.multicall{value: amount}(data);

        assertEq(size.getUserView(alice).collateralTokenBalance, amount);
    }

    function test_Multicall_multicall_cannot_deposit_twice() public {
        vm.startPrank(alice);
        uint256 amount = 1 wei;
        vm.deal(alice, 2 * amount);

        assertEq(size.getUserView(alice).collateralTokenBalance, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: address(weth), amount: amount, to: alice})));
        data[1] = abi.encodeCall(size.deposit, (DepositParams({token: address(weth), amount: amount, to: alice})));
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MSG_VALUE.selector, 2 * amount));
        size.multicall{value: 2 * amount}(data);
    }

    function test_Multicall_multicall_cannot_execute_unauthorized_actions() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount, to: alice})));
        data[1] = abi.encodeCall(size.grantRole, (0x00, alice));
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, 0x00));
        size.multicall(data);
    }

    function test_Multicall_liquidator_can_liquidate_and_withdraw() public {
        _setPrice(1e18);
        _setKeeperRole(liquidator);

        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 150e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 1e18));
        uint256 amount = 40e6;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        DebtPosition memory debtPosition = size.getDebtPosition(debtPositionId);
        uint256 futureValue = debtPosition.futureValue;

        _setPrice(0.6e18);

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        _mint(address(usdc), liquidator, futureValue);
        _approve(liquidator, address(usdc), address(size), futureValue);

        Vars memory _before = _state();
        uint256 beforeLiquidatorUSDC = usdc.balanceOf(liquidator);
        uint256 beforeLiquidatorWETH = weth.balanceOf(liquidator);

        bytes[] memory data = new bytes[](4);
        // deposit only the necessary to cover for the loan's futureValue
        data[0] =
            abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: futureValue, to: liquidator}));
        // liquidate profitably (but does not enforce CR)
        data[1] = abi.encodeCall(
            size.liquidate,
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: 0, deadline: type(uint256).max})
        );
        // withdraw everything
        data[2] = abi.encodeCall(
            size.withdraw, WithdrawParams({token: address(weth), amount: type(uint256).max, to: liquidator})
        );
        data[3] = abi.encodeCall(
            size.withdraw, WithdrawParams({token: address(usdc), amount: type(uint256).max, to: liquidator})
        );
        vm.prank(liquidator);
        size.multicall(data);

        Vars memory _after = _state();
        uint256 afterLiquidatorUSDC = usdc.balanceOf(liquidator);
        uint256 afterLiquidatorWETH = weth.balanceOf(liquidator);

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - futureValue, 0);
        assertEq(_after.liquidator.borrowTokenBalance, _before.liquidator.borrowTokenBalance, 0);
        assertEq(_after.liquidator.collateralTokenBalance, _before.liquidator.collateralTokenBalance, 0);
        assertGt(
            _after.feeRecipient.collateralTokenBalance,
            _before.feeRecipient.collateralTokenBalance,
            "feeRecipient has liquidation split"
        );
        assertEq(beforeLiquidatorWETH, 0);
        assertGt(afterLiquidatorWETH, beforeLiquidatorWETH);
        assertEq(beforeLiquidatorUSDC, futureValue);
        assertEq(afterLiquidatorUSDC, 0);
    }

    function test_Multicall_multicall_bypasses_cap_if_it_is_to_reduce_debt() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);
        uint256 amount = 100e6;
        uint256 cap = amount;
        _updateConfig("borrowTokenCap", cap);

        _deposit(alice, usdc, cap);
        _deposit(bob, weth, 200e18);

        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0.1e18));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, 365 days, false);
        uint256 futureValue = size.getDebtPosition(debtPositionId).futureValue;

        vm.warp(block.timestamp + 365 days);

        assertEq(_state().bob.debtBalance, futureValue);

        uint256 remaining = futureValue - size.getUserView(bob).borrowTokenBalance;
        _mint(address(usdc), bob, remaining);
        _approve(bob, address(usdc), address(size), remaining);

        // attempt to deposit to repay, but it reverts due to cap
        vm.expectRevert(abi.encodeWithSelector(Errors.BORROW_TOKEN_CAP_EXCEEDED.selector, cap, cap + remaining));
        vm.prank(bob);
        size.deposit(DepositParams({token: address(usdc), amount: remaining, to: bob}));

        assertEq(_state().bob.debtBalance, futureValue);

        // debt reduction is allowed to go over cap
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: remaining, to: bob}));
        data[1] = abi.encodeCall(size.repay, RepayParams({debtPositionId: debtPositionId, borrower: bob}));
        vm.prank(bob);
        size.multicall(data);

        assertEq(_state().bob.debtBalance, 0);
    }

    function test_Multicall_multicall_cannot_bypass_cap_if_it_is_not_to_reduce_debt() public {
        _setPrice(1e18);
        uint256 cap = 100e6;
        _mint(address(usdc), alice, cap + 1);
        _approve(alice, address(usdc), address(size), cap + 1);
        _updateConfig("borrowTokenCap", cap);

        // should not go over cap
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: cap + 1, to: alice}));
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.BORROW_TOKEN_INCREASE_EXCEEDS_DEBT_TOKEN_DECREASE.selector, cap + 1, 0)
        );
        size.multicall(data);
    }

    function test_Multicall_repay_when_borrowAToken_cap(uint256 index, uint256 amount) public {
        IERC20Metadata debtToken = IERC20Metadata(address(size.data().debtToken));

        index = bound(index, 1e27, 2e27);
        amount = bound(amount, 100e6, 200e6);

        _setLiquidityIndex(index);
        uint256 cap = 1000e6;
        _updateConfig("borrowTokenCap", cap);

        uint256 tenor = 365 days;
        _deposit(alice, usdc, cap);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(tenor, 0.03e18));

        _deposit(bob, weth, 100e18);
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, amount, tenor, false);

        _withdraw(bob, usdc, size.getUserView(bob).borrowTokenBalance);

        uint256 debtAmount = debtToken.balanceOf(bob);
        uint256 currentDeposit = size.getUserView(bob).borrowTokenBalance;
        uint256 depositRequiredToRepay = debtAmount - currentDeposit;
        _mint(address(usdc), bob, depositRequiredToRepay);
        _approve(bob, address(usdc), address(size), depositRequiredToRepay);

        bytes[] memory data = new bytes[](3);
        data[0] =
            abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: depositRequiredToRepay, to: bob}));
        data[1] = abi.encodeCall(size.repay, RepayParams({debtPositionId: debtPositionId, borrower: bob}));
        data[2] =
            abi.encodeCall(size.withdraw, WithdrawParams({token: address(usdc), amount: type(uint256).max, to: bob}));

        vm.prank(bob);
        size.multicall(data);

        assertEq(debtToken.balanceOf(bob), 0);
    }

    function test_Multicall_multicall_can_deposit_on_behalf_and_create_loanOffer_on_behalf() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        Action[] memory actions = new Action[](2);
        actions[0] = Action.BUY_CREDIT_LIMIT;
        actions[1] = Action.DEPOSIT;

        sizeFactory.setAuthorization(bob, Authorization.getActionsBitmap(actions));

        vm.startPrank(bob);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(
            size.depositOnBehalfOf,
            (DepositOnBehalfOfParams((DepositParams({token: token, amount: amount, to: alice})), alice))
        );
        data[1] = abi.encodeCall(
            size.buyCreditLimitOnBehalfOf,
            (
                BuyCreditLimitOnBehalfOfParams(
                    BuyCreditLimitParams({
                        maxDueDate: block.timestamp + 1 days,
                        curveRelativeTime: YieldCurveHelper.flatCurve()
                    }),
                    alice
                )
            )
        );
        bytes[] memory results = size.multicall(data);

        assertEq(results.length, 2);
        assertEq(results[0], bytes(""));
        assertEq(results[1], bytes(""));
    }
}
