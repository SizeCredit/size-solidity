// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";

import {CreditPosition, DebtPosition} from "@src/libraries/LoanLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract SetUserConfigurationTest is BaseTest {
    function test_SetUserConfiguration_setCreditForSale_disable_all() public {
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
        _sellCreditLimit(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 tenor = 6 * 30 days;
        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, RESERVED_ID, 975.94e6, tenor, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 futureValue = size.getDebtPosition(debtPositionId1).futureValue;

        CreditPosition memory creditPosition = size.getCreditPosition(creditPositionId1_1);
        assertEq(creditPosition.lender, alice);
        _setUserConfiguration(alice, 0, true, false, new uint256[](0));

        vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_NOT_FOR_SALE.selector, creditPositionId1_1));
        _buyCreditMarket(james, alice, creditPositionId1_1, futureValue, tenor, false);
    }

    function test_SetUserConfiguration_setCreditForSale_disable_single() public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);

        _updateConfig("borrowATokenCap", type(uint256).max);

        _deposit(alice, usdc, 2 * 1000e6);
        _deposit(bob, weth, 2 * 1600e18);
        _deposit(james, weth, 1600e18);
        _deposit(james, usdc, 1000e6);
        _deposit(candy, usdc, 1200e6);
        _buyCreditLimit(alice, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(6 * 30 days, 0.05e18));
        _buyCreditLimit(candy, block.timestamp + 12 * 30 days, YieldCurveHelper.pointCurve(7 * 30 days, 0));
        _sellCreditLimit(alice, YieldCurveHelper.pointCurve(6 * 30 days, 0.04e18));

        uint256 tenor = 6 * 30 days;
        uint256 debtPositionId1 = _sellCreditMarket(bob, alice, RESERVED_ID, 975.94e6, tenor, false);
        uint256 creditPositionId1_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId1)[0];
        uint256 futureValue1 = size.getDebtPosition(debtPositionId1).futureValue;
        uint256 debtPositionId2 = _sellCreditMarket(bob, alice, RESERVED_ID, 500e6, tenor, false);
        uint256 creditPositionId2_1 = size.getCreditPositionIdsByDebtPositionId(debtPositionId2)[0];
        uint256 futureValue2 = size.getDebtPosition(debtPositionId2).futureValue;

        uint256[] memory creditPositionIds = new uint256[](1);
        creditPositionIds[0] = creditPositionId1_1;
        _setUserConfiguration(alice, 0, false, false, creditPositionIds);

        // vm.expectRevert(abi.encodeWithSelector(Errors.CREDIT_NOT_FOR_SALE.selector, creditPositionId1_1));
        vm.expectRevert();
        _buyCreditMarket(james, alice, creditPositionId1_1, futureValue1, tenor, false);

        _buyCreditMarket(james, alice, creditPositionId2_1, futureValue2, tenor, false);
    }
}
