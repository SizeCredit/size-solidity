// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract BuyMarketCreditTest is BaseTest {
    function test_BuyMarketCredit_buyMarketCredit_experiment_strategy_credit_dealer() public {
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
        uint256 debtPositionId2 = _borrowAsMarketOrder(james, candy, 1000.004274e6, block.timestamp + 7 * 30 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        assertEq(size.getDebtPosition(debtPositionId1).faceValue, 1000.004274e6);
        assertEq(_state().alice.borrowATokenBalance, 24.06e6);
        assertEqApprox(_state().james.borrowATokenBalance, 2000e6, 0.01e6);

        _buyMarketCredit(james, creditPositionId1_1, size.getDebtPosition(debtPositionId1).faceValue, false);

        assertEqApprox(_state().james.borrowATokenBalance, 2000e6 - 980.66e6, 0.01e6);

        uint256 creditPositionId1_2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[1];
        _compensate(james, creditPositionId2_1, creditPositionId1_2);

        assertEqApprox(_state().alice.borrowATokenBalance, 1004e6, 1e6);
    }

    function test_BuyMarketCredit_buyMarketCredit_exactAmountIn() public {
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
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 debtPositionId1 = _borrowAsMarketOrder(bob, alice, 975.94e6, block.timestamp + 6 * 30 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];

        assertEq(size.getDebtPosition(debtPositionId1).faceValue, 1000.004274e6);
        assertEq(_state().alice.borrowATokenBalance, 24.06e6);
        assertEqApprox(_state().james.borrowATokenBalance, 1000e6, 0.01e6);

        uint256 faceValue = size.getDebtPosition(debtPositionId1).faceValue;
        uint256 required = Math.mulDivDown(faceValue, PERCENT + 0.04e18 * 6 * uint256(30 days) / 365 days, PERCENT);
        uint256 credit = size.getCreditPosition(creditPositionId1_1).credit;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.NOT_ENOUGH_CREDIT.selector, creditPositionId1_1, credit, required)
        );
        _buyMarketCredit(james, creditPositionId1_1, faceValue, true);

        uint256 amountIn =
            Math.mulDivDown(size.getCreditPosition(creditPositionId1_1).credit, PERCENT, PERCENT + 0.05e18);

        _buyMarketCredit(james, creditPositionId1_1, amountIn, true);

        assertEqApprox(_state().james.borrowATokenBalance, 1000e6 - amountIn, 0.01e6);
    }
}
