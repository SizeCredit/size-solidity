// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {LiquidateParams} from "@src/libraries/actions/Liquidate.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateValidationTest is BaseTest {
    function test_Liquidate_validation() public {
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 100e18);
        _deposit(bob, usdc, 100e6);
        _deposit(candy, weth, 100e18);
        _deposit(candy, usdc, 150e6);
        _deposit(james, weth, 100e18);
        _deposit(james, usdc, 150e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        _buyCreditLimit(bob, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        _buyCreditLimit(james, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0.03e18));
        _sellCreditMarket(bob, candy, RESERVED_ID, 90e6, 12 days, false);

        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(alice, james, creditId, 20e6, 12 days);
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

        _sellCreditMarket(alice, candy, creditId, 10e6, 12 days);
        _sellCreditMarket(alice, james, RESERVED_ID, 50e6, 12 days, false);

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
