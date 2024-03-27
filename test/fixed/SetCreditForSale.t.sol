// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract SetCreditForSaleTest is BaseTest {
    function test_SetCreditForSale_setCreditForSale_disable_all() public {
        _setPrice(1e18);
        _updateConfig("earlyLenderExitFee", 0);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _lendAsLimitOrder(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _borrowAsMarketOrder(bob, alice, 975.94e6, block.timestamp + 6 * 30 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 faceValue = size.getDebtPosition(debtPositionId1).faceValue;

        _setCreditForSale(alice, new uint256[](0), false, true);

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_NOT_FOR_SALE.selector, creditPositionId1_1));
        _buyMarketCredit(james, creditPositionId1_1, faceValue, false);
    }

    function test_SetCreditForSale_setCreditForSale_disable_single() public {
        _setPrice(1e18);
        _updateConfig("earlyLenderExitFee", 0);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 2 * 1000e6);
        _deposit(bob, weth, 2 * 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _lendAsLimitOrder(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _borrowAsMarketOrder(bob, alice, 975.94e6, block.timestamp + 6 * 30 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 faceValue1 = size.getDebtPosition(debtPositionId1).faceValue;
        uint256 debtPositionId2 = _borrowAsMarketOrder(bob, alice, 500e6, block.timestamp + 6 * 30 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        uint256 faceValue2 = size.getDebtPosition(debtPositionId2).faceValue;

        uint256[] memory creditPositionIds = new uint256[](1);
        creditPositionIds[0] = creditPositionId1_1;
        _setCreditForSale(alice, creditPositionIds, false, false);

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_NOT_FOR_SALE.selector, creditPositionId1_1));
        _buyMarketCredit(james, creditPositionId1_1, faceValue1, false);

        _buyMarketCredit(james, creditPositionId2_1, faceValue2, false);
    }
}
