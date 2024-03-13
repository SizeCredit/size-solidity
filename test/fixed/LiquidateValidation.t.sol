// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {LiquidateParams} from "@src/libraries/fixed/actions/Liquidate.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateValidationTest is BaseTest {
    function test_Liquidate_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6 + size.feeConfig().earlyLenderExitFee);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 100e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(bob, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(candy, block.timestamp + 12 days, 0.03e18);
        _lendAsLimitOrder(james, block.timestamp + 12 days, 0.03e18);
        _borrowAsMarketOrder(bob, candy, 90e6, block.timestamp + 12 days);

        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 12 days);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _borrowAsMarketOrder(alice, james, 5e6, block.timestamp + 12 days, [creditId]);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[1];
        uint256 minimumCollateralProfit = 0;

        _deposit(liquidator, usdc, 10_000e6);

        vm.startPrank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DEBT_POSITION_ID.selector, creditPositionId));
        size.liquidate(
            LiquidateParams({debtPositionId: creditPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );
        vm.stopPrank();

        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, debtPositionId, size.collateralRatio(bob), LoanStatus.ACTIVE
            )
        );
        size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );
        vm.stopPrank();

        _borrowAsMarketOrder(alice, candy, 10e6, block.timestamp + 12 days, [creditId]);
        _borrowAsMarketOrder(alice, james, 50e6, block.timestamp + 12 days);

        // DebtPosition with high CR cannot be liquidated
        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, debtPositionId, size.collateralRatio(bob), LoanStatus.ACTIVE
            )
        );
        size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );
        vm.stopPrank();

        _setPrice(0.01e18);

        // CreditPosition cannot be liquidated
        vm.startPrank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_DEBT_POSITION_ID.selector, creditPositionId));
        size.liquidate(
            LiquidateParams({debtPositionId: creditPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );
        vm.stopPrank();

        _setPrice(100e18);
        _repay(bob, debtPositionId);
        _withdraw(bob, weth, 98e18);

        _setPrice(0.2e18);

        // REPAID loan cannot be liquidated
        vm.startPrank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_LIQUIDATABLE.selector, debtPositionId, size.collateralRatio(bob), LoanStatus.REPAID
            )
        );
        size.liquidate(
            LiquidateParams({debtPositionId: debtPositionId, minimumCollateralProfit: minimumCollateralProfit})
        );
        vm.stopPrank();
    }
}
