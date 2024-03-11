// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";
import {Vars} from "@test/BaseTestGeneral.sol";

import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ConversionLibrary} from "@src/libraries/ConversionLibrary.sol";

import {Math} from "@src/libraries/Math.sol";
import {DepositParams} from "@src/libraries/fixed/actions/Deposit.sol";
import {LendAsLimitOrderParams} from "@src/libraries/fixed/actions/LendAsLimitOrder.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";
import {WithdrawParams} from "@src/libraries/fixed/actions/Withdraw.sol";

import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract MulticallTest is BaseTest {
    function test_Multicall_multicall_can_deposit_and_create_loanOffer() public {
        vm.startPrank(alice);
        uint256 amount = 100e6;
        address token = address(usdc);
        deal(token, alice, amount);
        IERC20Metadata(token).approve(address(size), amount);

        assertEq(size.getUserView(alice).borrowATokenBalance, 0);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeCall(size.deposit, (DepositParams({token: token, amount: amount, to: alice})));
        data[1] = abi.encodeCall(
            size.lendAsLimitOrder,
            LendAsLimitOrderParams({
                maxDueDate: block.timestamp + 1 days,
                curveRelativeTime: YieldCurveHelper.flatCurve()
            })
        );
        size.multicall(data);

        assertEq(size.getUserView(alice).borrowATokenBalance, amount);
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
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);

        _lendAsLimitOrder(alice, block.timestamp + 365 days, 0.03e18);
        uint256 amount = 15e6;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, amount, block.timestamp + 365 days);
        uint256 faceValue = size.getDebtPosition(debtPositionId).faceValue;
        uint256 repayFee = size.repayFee(debtPositionId);
        uint256 repayFeeWad = ConversionLibrary.amountToWad(repayFee, usdc.decimals());
        uint256 debt = faceValue + repayFee;

        _setPrice(0.2e18);

        uint256 repayFeeCollateral = Math.mulDivUp(repayFeeWad, 10 ** priceFeed.decimals(), priceFeed.getPrice());

        assertTrue(size.isDebtPositionLiquidatable(debtPositionId));

        _mint(address(usdc), liquidator, faceValue);
        _approve(liquidator, address(usdc), address(size), faceValue);

        Vars memory _before = _state();
        uint256 beforeLiquidatorUSDC = usdc.balanceOf(liquidator);
        uint256 beforeLiquidatorWETH = weth.balanceOf(liquidator);

        bytes[] memory data = new bytes[](4);
        // deposit only the necessary to cover for the loan's faceValue
        data[0] = abi.encodeCall(size.deposit, DepositParams({token: address(usdc), amount: faceValue, to: liquidator}));
        // liquidate profitably (but does not enforce CR)
        data[1] = abi.encodeCall(
            size.liquidate, LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: 0})
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

        assertEq(_after.bob.debtBalance, _before.bob.debtBalance - debt, 0);
        assertEq(_after.liquidator.borrowATokenBalance, _before.liquidator.borrowATokenBalance, 0);
        assertEq(_after.liquidator.collateralBalance, _before.liquidator.collateralBalance, 0);
        assertGt(
            _after.feeRecipient.collateralBalance,
            _before.feeRecipient.collateralBalance + repayFeeCollateral,
            "feeRecipient has repayFee and liquidation split"
        );
        assertEq(beforeLiquidatorWETH, 0);
        assertGt(afterLiquidatorWETH, beforeLiquidatorWETH);
        assertEq(beforeLiquidatorUSDC, faceValue);
        assertEq(afterLiquidatorUSDC, 0);
    }
}
