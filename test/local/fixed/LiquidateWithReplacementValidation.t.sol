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
        _setPrice(1e18);
        _deposit(alice, weth, 100e18);
        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 100e18);
        _deposit(candy, weth, 200e18);
        _deposit(bob, usdc, 100e6);
        _deposit(liquidator, weth, 100e18);
        _deposit(liquidator, usdc, 100e6);
        _buyCreditLimit(
            alice,
            block.timestamp + 365 days * 2,
            [int256(0.03e18), int256(0.03e18)],
            [uint256(365 days), uint256(365 days * 2)]
        );
        _sellCreditLimit(candy, [int256(0.03e18), int256(0.03e18)], [uint256(365 days), uint256(365 days * 2)]);
        uint256 tenor = 365 days * 2;
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 15e6, tenor, false);
        uint256 minimumCollateralProfit = 0;

        _setPrice(0.2e18);

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
        _sellCreditLimit(candy, empty);

        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_BORROW_OFFER.selector, candy));
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

        _sellCreditLimit(candy, [int256(0.03e18), int256(0.03e18)], [uint256(365 days), uint256(365 days * 2)]);

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
