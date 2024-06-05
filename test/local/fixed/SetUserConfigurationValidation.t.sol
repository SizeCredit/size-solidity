// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {SetUserConfigurationParams} from "@src/libraries/actions/SetUserConfiguration.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {Errors} from "@src/libraries/Errors.sol";

contract SetUserConfigurationValidationTest is BaseTest {
    function test_SetUserConfiguration_validation() public {
        _setPrice(1e18);
        _updateConfig("fragmentationFee", 0);

        _deposit(alice, usdc, 150e6);
        _deposit(bob, weth, 200e18);
        _buyCreditLimit(alice, block.timestamp + 365 days, YieldCurveHelper.pointCurve(365 days, 0));
        uint256 debtPositionId = _sellCreditMarket(bob, alice, RESERVED_ID, 100e6, 365 days, false);
        uint256 creditPositionId = size.getCreditPositionIdsByDebtPositionId(debtPositionId)[0];

        uint256[] memory creditPositionIds = new uint256[](1);
        creditPositionIds[0] = creditPositionId;

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_CREDIT_POSITION_ID.selector, creditPositionId));
        size.setUserConfiguration(
            SetUserConfigurationParams({
                openingLimitBorrowCR: 0,
                allCreditPositionsForSaleDisabled: false,
                creditPositionIdsForSale: true,
                creditPositionIds: creditPositionIds
            })
        );

        _deposit(bob, usdc, 100e6);
        _repay(bob, debtPositionId);
        _claim(alice, creditPositionId);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.LOAN_NOT_ACTIVE.selector, creditPositionId));
        size.setUserConfiguration(
            SetUserConfigurationParams({
                openingLimitBorrowCR: 0,
                allCreditPositionsForSaleDisabled: false,
                creditPositionIdsForSale: true,
                creditPositionIds: creditPositionIds
            })
        );
    }
}
