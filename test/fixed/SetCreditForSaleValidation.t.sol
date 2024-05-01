// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {SetCreditForSaleParams} from "@src/libraries/fixed/actions/SetCreditForSale.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SetCreditForSaleValidationTest is BaseTest {
    function test_SetCreditForSale_validation() public {
        _setPrice(1e18);
        _updateConfig("earlyLenderExitFee", 0);
        _updateConfig("repayFeeAPR", 0);
        _updateConfig("overdueLiquidatorReward", 0);

        _deposit(alice, usdc, 2 * 100e6);
        _deposit(bob, weth, 2 * 150e18);
        _deposit(candy, usdc, 100e6);
        _lendAsLimitOrder(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        _lendAsLimitOrder(candy, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];
        uint256 debtPositionId2 = _borrowAsMarketOrder(bob, alice, 100e6, block.timestamp + 365 days);
        uint256 creditPositionId2 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        _borrowAsMarketOrder(alice, candy, 100e6, block.timestamp + 365 days, [creditPositionId2]);

        uint256[] memory creditPositionIds = new uint256[](1);
        creditPositionIds[0] = creditPositionId;

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, creditPositionId));
        size.setCreditForSale(
            SetCreditForSaleParams({
                creditPositionIds: creditPositionIds,
                forSale: true,
                creditPositionsForSaleDisabled: false
            })
        );

        _deposit(bob, usdc, 100e6);
        _repay(bob, debtPositionId);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, creditPositionId));
        size.setCreditForSale(
            SetCreditForSaleParams({
                creditPositionIds: creditPositionIds,
                forSale: true,
                creditPositionsForSaleDisabled: false
            })
        );

        creditPositionIds[0] = creditPositionId2;
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_POSITION_ALREADY_CLAIMED.selector, creditPositionId2));
        size.setCreditForSale(
            SetCreditForSaleParams({
                creditPositionIds: creditPositionIds,
                forSale: true,
                creditPositionsForSaleDisabled: false
            })
        );
    }
}
