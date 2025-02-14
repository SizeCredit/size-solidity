// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";
import {CopyLimitOrder} from "@src/libraries/OfferLibrary.sol";
import {YieldCurve} from "@src/libraries/YieldCurveLibrary.sol";

import {OfferLibrary} from "@src/libraries/OfferLibrary.sol";
import {CopyLimitOrdersParams} from "@src/libraries/actions/CopyLimitOrders.sol";
import {BaseTest} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract CopyLimitOrdersValidationTest is BaseTest {
    CopyLimitOrder private nullCopy;
    CopyLimitOrder private fullCopy =
        CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0, maxAPR: type(uint256).max, offsetAPR: 0});

    function test_CopyLimitOrders_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        _copyLimitOrders(alice, address(0), fullCopy, nullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ADDRESS.selector, bob));
        _copyLimitOrders(alice, bob, nullCopy, nullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TENOR_RANGE.selector, 3 days, 1 days));
        _copyLimitOrders(
            alice,
            bob,
            CopyLimitOrder({minTenor: 3 days, maxTenor: 1 days, minAPR: 0, maxAPR: 0, offsetAPR: 0}),
            nullCopy
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TENOR_RANGE.selector, 5 days, 2 days));
        _copyLimitOrders(
            alice,
            bob,
            nullCopy,
            CopyLimitOrder({minTenor: 5 days, maxTenor: 2 days, minAPR: 0, maxAPR: 0, offsetAPR: 0})
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ADDRESS.selector, alice));
        _copyLimitOrders(alice, alice, fullCopy, fullCopy);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_APR_RANGE.selector, 0.1e18, 0.05e18));
        _copyLimitOrders(
            alice,
            bob,
            CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0.1e18, maxAPR: 0.05e18, offsetAPR: 0}),
            fullCopy
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_APR_RANGE.selector, 0.2e18, 0.1e18));
        _copyLimitOrders(
            alice,
            bob,
            fullCopy,
            CopyLimitOrder({minTenor: 0, maxTenor: type(uint256).max, minAPR: 0.2e18, maxAPR: 0.1e18, offsetAPR: 0})
        );
    }
}
