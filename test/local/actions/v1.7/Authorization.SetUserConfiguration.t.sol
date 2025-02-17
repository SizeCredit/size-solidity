// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/SizeView.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {CreditPosition, RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {
    SetUserConfigurationOnBehalfOfParams,
    SetUserConfigurationParams
} from "@src/libraries/actions/SetUserConfiguration.sol";

import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationSetUserConfigurationTest is BaseTest {
    function test_AuthorizationSetUserConfiguration_setUserConfigurationOnBehalfOf() public {
        _setAuthorization(alice, candy, size, Authorization.getActionsBitmap(Action.SET_USER_CONFIGURATION));

        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);

        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 1000e6);
        _deposit(bob, weth, 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _buyCreditLimit(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _buyCreditLimit(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _sellCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 tenor = 6 * 30 days;
        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, RESERVED_ID, 975.94e6, tenor, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 futureValue = size.getDebtPosition(debtPositionId1).futureValue;

        CreditPosition memory creditPosition = size.getCreditPosition(creditPositionId1_1);
        assertEq(creditPosition.lender, alice);

        vm.prank(candy);
        size.setUserConfigurationOnBehalfOf(
            SetUserConfigurationOnBehalfOfParams({
                params: SetUserConfigurationParams({
                    openingLimitBorrowCR: 0,
                    allCreditPositionsForSaleDisabled: true,
                    creditPositionIdsForSale: false,
                    creditPositionIds: new uint256[](0)
                }),
                onBehalfOf: alice
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_NOT_FOR_SALE.selector, creditPositionId1_1));
        _buyCreditMarket(james, alice, creditPositionId1_1, futureValue, tenor, false);
    }

    function test_AuthorizationSetUserConfiguration_validation() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.SET_USER_CONFIGURATION)
        );
        vm.prank(alice);
        size.setUserConfigurationOnBehalfOf(
            SetUserConfigurationOnBehalfOfParams({
                params: SetUserConfigurationParams({
                    openingLimitBorrowCR: 0,
                    allCreditPositionsForSaleDisabled: true,
                    creditPositionIdsForSale: false,
                    creditPositionIds: new uint256[](0)
                }),
                onBehalfOf: bob
            })
        );
    }
}
