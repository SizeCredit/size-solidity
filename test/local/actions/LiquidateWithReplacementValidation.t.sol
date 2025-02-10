// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";
import {LiquidateWithReplacementParams} from "@src/libraries/actions/LiquidateWithReplacement.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract LiquidateWithReplacementValidationTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setKeeperRole(liquidator);
    }

    function test_LiquidateWithReplacement_validation() public {
        vm.warp(42 days);

        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(candy, weth, 200e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        uint256 maxDueDate1 = block.timestamp + 365 days * 2;
        _buyCreditLimit(
            alice, maxDueDate1, [int256(0.03e18), int256(0.03e18)], [uint256(365 days), uint256(365 days * 2)]
        );
        uint256 maxDueDate2 = block.timestamp + 365 days;
        _sellCreditLimit(
            candy, maxDueDate2, [int256(0.03e18), int256(0.03e18)], [uint256(365 days), uint256(365 days * 2)]
        );
        uint256 tenor = 365 days * 2;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 15e6, tenor, false);
        uint256 minimumCollateralProfit = 0;

        _setPrice(0.2e18);

        vm.prank(liquidator);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DUE_DATE_GREATER_THAN_MAX_DUE_DATE.selector, block.timestamp + tenor, maxDueDate2
            )
        );
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minAPR: 1e18,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        _sellCreditLimit(
            candy,
            block.timestamp + 3 * 365 days,
            [int256(0.03e18), int256(0.03e18)],
            [uint256(365 days), uint256(365 days * 2)]
        );

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.APR_LOWER_THAN_MIN_APR.selector, 0.03e18, 1e18));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minAPR: 1e18,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, block.timestamp - 1));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minAPR: 0,
                deadline: block.timestamp - 1,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        YieldCurve memory empty;
        _sellCreditLimit(candy, 0, empty);

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_OFFER.selector, candy));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minAPR: 0,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        vm.warp(block.timestamp + 365 days * 2);

        uint256 minTenor = size.riskConfig().minTenor;
        uint256 maxTenor = size.riskConfig().maxTenor;

        _sellCreditLimit(
            candy,
            block.timestamp + 365 days,
            [int256(0.03e18), int256(0.03e18)],
            [uint256(365 days), uint256(365 days * 2)]
        );

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.TENOR_OUT_OF_RANGE.selector, 0, minTenor, maxTenor));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minAPR: 0,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        vm.warp(block.timestamp + 1);

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, debtPositionId));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minAPR: 0,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );
    }
}
