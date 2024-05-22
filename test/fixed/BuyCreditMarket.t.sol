// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyCreditMarketTest is BaseTest {
    function test_BuyCreditMarket_basicFunctionality() public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);
        _updateConfig("swapFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(candy, usdc, 1200e6);

        uint256 dueDate = block.timestamp + 365 days;
        _lendAsLimitOrder(alice, dueDate, YieldCurveHelper.pointCurve(365 days, 0.05e18));
        uint256 debtPositionId = _borrow(bob, alice, 975.94e6, dueDate);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        // Test buying credit market
        _buyCreditMarket(james, creditPositionId, 500e6, true, dueDate, address(0)); // Buying credit
        _buyCreditMarket(candy, 0, 500e6, true, dueDate, bob); // Lending as market order

        // Assertions to verify the state after transactions
        assertEq(size.getDebtPosition(debtPositionId).faceValue, 975.94e6);
        assertEq(_state().james.borrowATokenBalance, 500e6);
        assertEq(_state().candy.borrowATokenBalance, 500e6);
    }
}