// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {BaseTest} from "@test/BaseTest.sol";

import {LiquidateWithReplacementParams} from "@src/libraries/fixed/actions/LiquidateWithReplacement.sol";

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
        _lendAsLimitOrder(
            alice,
            block.timestamp + 365 days * 2,
            [int256(0.03e18), int256(0.03e18)],
            [uint256(365 days), uint256(365 days * 2)]
        );
        _borrowAsLimitOrder(candy, [int256(0.03e18), int256(0.03e18)], [uint256(365 days), uint256(365 days * 2)]);
        uint256 dueDate = block.timestamp + 365 days * 2;
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 15e6, dueDate);
        uint256 minimumCollateralProfit = 0;

        _setPrice(0.2e18);

        vm.startPrank(liquidator);

        vm.expectRevert(
            abi.encodeWithSelector(Errors.RATE_PER_MATURITY_LOWER_THAN_MIN_RATE.selector, 0.03e18 * 2, 1e18)
        );
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minRatePerMaturity: 1e18,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        uint256 deadline = block.timestamp;
        vm.warp(block.timestamp + 365 days);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, deadline));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minRatePerMaturity: 0,
                deadline: deadline,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );

        vm.warp(block.timestamp + 365 days * 2);

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DUE_DATE.selector, dueDate));
        size.liquidateWithReplacement(
            LiquidateWithReplacementParams({
                debtPositionId: debtPositionId,
                borrower: candy,
                minRatePerMaturity: 0,
                deadline: block.timestamp,
                minimumCollateralProfit: minimumCollateralProfit
            })
        );
    }
}
