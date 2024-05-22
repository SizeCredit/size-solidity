// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyCreditMarketTest is BaseTest {

    function test_BuyCreditMarket_buy_existing_credit() public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _lendAsLimitOrder(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _lendAsLimitOrder(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _borrow(bob, alice, 975.94e6, block.timestamp + 6 * 30 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];
        uint256 debtPositionId2 = _borrow(james, candy, 1000.004274e6, block.timestamp + 7 * 30 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[1];

        assertEq(size.getDebtPosition(debtPositionId1).faceValue, 1000.004274e6);
        assertEq(_state().alice.borrowATokenBalance, 24.06e6);
        assertEqApprox(_state().james.borrowATokenBalance, 2000e6, 0.01e6);

        // _buyMarketCredit(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).faceValue, false);
        _buyCreditMarket(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).faceValue, false, 0, address(0)); // Buying credit

        assertEqApprox(_state().james.borrowATokenBalance, 2000e6 - 980.66e6, 0.01e6);

        uint256 creditPositionId1_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[2];
        _compensate(james, creditPositionId2_1, creditPositionId1_2);

        assertEqApprox(_state().alice.borrowATokenBalance, 1004e6, 1e6);
    }
}