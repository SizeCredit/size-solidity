// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationSetAuthorizationTest is BaseTest {
    function test_AuthorizationSetAuthorization_setAuthorization() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(alice, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(candy, alice, Action.SELL_CREDIT_MARKET));

        assertTrue(!sizeFactory.isAuthorized(alice, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(bob, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(candy, bob, Action.SELL_CREDIT_MARKET));

        assertTrue(!sizeFactory.isAuthorized(alice, candy, Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(bob, candy, Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(candy, candy, Action.SELL_CREDIT_MARKET));
    }

    function test_AuthorizationSetAuthorization_validation() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        vm.prank(alice);
        sizeFactory.setAuthorization(address(0), Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTIONS_BITMAP.selector, type(uint256).max));
        vm.prank(alice);
        sizeFactory.setAuthorization(bob, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTION.selector, Action.LAST_ACTION));
        Authorization.getActionsBitmap(Action.LAST_ACTION);
    }

    function test_AuthorizationSetAuthorization_isAuthorized() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.SELL_CREDIT_MARKET));
    }
}
