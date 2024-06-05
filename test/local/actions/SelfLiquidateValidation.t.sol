// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

import {LoanStatus, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {SelfLiquidateParams} from "@src/libraries/actions/SelfLiquidate.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SelfLiquidateValidationTest is BaseTest {
    function test_SelfLiquidate_validation() public {
        _setPrice(1e18);
        _updateConfig("swapFeeAPR", 0);

        _deposit(alice, usdc, 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(candy, usdc, 100e6);
        _buyCreditLimit(alice, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        _buyCreditLimit(candy, block.timestamp + 12 days, YieldCurveHelper.pointCurve(12 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 12 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        _sellCreditMarket(bob, candy, RESERVED_ID, 100e6, 12 days, false);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector, creditPositionId, 1.5e18, LoanStatus.ACTIVE
            )
        );
        size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));
        vm.stopPrank();

        _setPrice(0.75e18);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATION_NOT_AT_LOSS.selector, creditPositionId, 1.125e18));
        size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));
        vm.stopPrank();

        _setPrice(0.5e18);

        vm.startPrank(james);
        vm.expectRevert(abi.encodeWithSelector(Errors.LIQUIDATOR_IS_NOT_LENDER.selector, james, alice));
        size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));
        vm.stopPrank();

        _setPrice(0.75e18);

        _repay(bob, debtPositionId);
        _setPrice(0.25e18);

        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.LOAN_NOT_SELF_LIQUIDATABLE.selector,
                creditPositionId,
                size.collateralRatio(bob),
                LoanStatus.REPAID
            )
        );
        size.selfLiquidate(SelfLiquidateParams({creditPositionId: creditPositionId}));
        vm.stopPrank();
    }
}
