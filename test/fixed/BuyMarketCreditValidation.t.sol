// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";
import {BuyMarketCreditParams} from "@src/libraries/fixed/actions/BuyMarketCredit.sol";

contract BuyMarketCreditValidationTest is BaseTest {
    function test_BuyMarketCredit_validation() public {
        _setPrice(1e18);
        _updateConfig("earlyLenderExitFee", 0);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);
        _updateConfig("collateralTokenCap", type(uint256).max);
        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 5000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _lendAsLimitOrder(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(365 days, 0.1e18));

        uint256 debtPositionId1 = _borrowAsMarketOrder(bob, alice, 500e6, block.timestamp + 365 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 debtPositionId2 = _borrowAsMarketOrder(james, candy, 1000.004274e6, block.timestamp + 365 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        vm.expectRevert(abi.encodeWithSelector(Errors.APR_GREATER_THAN_MAX_APR.selector, 0.1e18, 0));
        size.buyMarketCredit(
            BuyMarketCreditParams({
                creditPositionId: creditPositionId1_1,
                amount: 500e6,
                exactAmountIn: false,
                deadline: block.timestamp,
                maxAPR: 0
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.PAST_DEADLINE.selector, 0));
        size.buyMarketCredit(
            BuyMarketCreditParams({
                creditPositionId: creditPositionId1_1,
                amount: 500e6,
                exactAmountIn: false,
                deadline: 0,
                maxAPR: type(uint256).max
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        _buyMarketCredit(bob, creditPositionId2_1, 500e6, false);

        _repay(bob, debtPositionId1);

        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, creditPositionId1_1));
        _buyMarketCredit(james, creditPositionId1_1, 500e6, false);

        _borrowAsLimitOrder(candy, YieldCurveHelper.pointCurve(365 days, 0.2e18));
        _borrowAsMarketOrder(
            candy,
            alice,
            size.getDebtPosition(debtPositionId2).faceValue,
            block.timestamp + 365 days,
            [creditPositionId2_1]
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionId2_1));
        _buyMarketCredit(james, creditPositionId2_1, 500e6, false);
    }
}
