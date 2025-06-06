// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/market/libraries/Errors.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/market/libraries/YieldCurveLibrary.sol";

import {OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";
import {CopyLimitOrdersParams} from "@src/market/libraries/actions/CopyLimitOrders.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract CopyLimitOrdersValidationTest is BaseTest {
    CopyLimitOrderConfig private nullCopy;
    CopyLimitOrderConfig private fullCopy = CopyLimitOrderConfig({
        minTenor: 0,
        maxTenor: type(uint256).max,
        minAPR: 0,
        maxAPR: type(uint256).max,
        offsetAPR: 0
    });

    function test_CopyLimitOrders_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TENOR_RANGE.selector, 3 days, 1 days));
        _copyLimitOrders(
            alice,
            CopyLimitOrderConfig({minTenor: 3 days, maxTenor: 1 days, minAPR: 0, maxAPR: 0, offsetAPR: 0}),
            nullCopy
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TENOR_RANGE.selector, 5 days, 2 days));
        _copyLimitOrders(
            alice,
            nullCopy,
            CopyLimitOrderConfig({minTenor: 5 days, maxTenor: 2 days, minAPR: 0, maxAPR: 0, offsetAPR: 0})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_APR_RANGE.selector, 0.1e18, 0.05e18));
        _copyLimitOrders(
            alice,
            CopyLimitOrderConfig({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0.1e18,
                maxAPR: 0.05e18,
                offsetAPR: 0
            }),
            fullCopy
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_APR_RANGE.selector, 0.2e18, 0.1e18));
        _copyLimitOrders(
            alice,
            fullCopy,
            CopyLimitOrderConfig({
                minTenor: 0,
                maxTenor: type(uint256).max,
                minAPR: 0.2e18,
                maxAPR: 0.1e18,
                offsetAPR: 0
            })
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.INVALID_OFFER_CONFIGS.selector,
                15 days,
                45 days,
                0.06e18,
                0.08e18,
                10 days,
                30 days,
                0.03e18,
                0.05e18
            )
        );
        _copyLimitOrders(
            alice,
            CopyLimitOrderConfig({minTenor: 10 days, maxTenor: 30 days, minAPR: 0.03e18, maxAPR: 0.05e18, offsetAPR: 0}),
            CopyLimitOrderConfig({minTenor: 15 days, maxTenor: 45 days, minAPR: 0.06e18, maxAPR: 0.08e18, offsetAPR: 0})
        );
    }
}
