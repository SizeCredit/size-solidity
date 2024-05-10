// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {LoanStatus} from "@src/libraries/fixed/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract BuyMarketCreditValidationTest is BaseTest {
    function test_BuyMarketCredit_validation() public {
        _setPrice(1e18);
        _updateConfig("earlyExitFee", 0);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);

        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _lendAsLimitOrder(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _borrowAsLimitOrder(alice, YieldCurveHelper.pointCurve(365 days, 0));

        uint256 debtPositionId1 = _borrowAsMarketOrder(bob, alice, 500e6, block.timestamp + 365 days);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 debtPositionId2 = _borrowAsMarketOrder(james, candy, 1000.004274e6, block.timestamp + 365 days);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_OFFER.selector));
        _buyMarketCredit(bob, creditPositionId2_1, 500e6, false);

        _repay(bob, debtPositionId1);

        uint256 cr = size.collateralRatio(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.CREDIT_POSITION_NOT_TRANSFERRABLE.selector, creditPositionId1_1, LoanStatus.REPAID, cr
            )
        );
        _buyMarketCredit(james, creditPositionId1_1, 500e6, false);
    }
}
