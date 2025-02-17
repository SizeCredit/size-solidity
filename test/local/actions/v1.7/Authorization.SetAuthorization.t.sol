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
        _setAuthorization(alice, bob, address(size), Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        assertTrue(sizeFactory.isAuthorized(bob, alice, address(size), Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(alice, alice, address(size), Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(candy, alice, address(size), Action.SELL_CREDIT_MARKET));

        assertTrue(!sizeFactory.isAuthorized(alice, bob, address(size), Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(bob, bob, address(size), Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(candy, bob, address(size), Action.SELL_CREDIT_MARKET));

        assertTrue(!sizeFactory.isAuthorized(alice, candy, address(size), Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(bob, candy, address(size), Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(candy, candy, address(size), Action.SELL_CREDIT_MARKET));
    }

    function test_AuthorizationSetAuthorization_validation() public {
        address market = address(size);

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        vm.prank(alice);
        sizeFactory.setAuthorization(address(0), market, Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MARKET.selector, address(0x42)));
        vm.prank(alice);
        sizeFactory.setAuthorization(bob, address(0x42), Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTIONS_BITMAP.selector, type(uint256).max));
        vm.prank(alice);
        sizeFactory.setAuthorization(bob, market, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTION.selector, Action.LAST_ACTION));
        Authorization.getActionsBitmap(Action.LAST_ACTION);
    }

    function test_AuthorizationSetAuthorization_isAuthorizedOnThisMarket() public {
        _setAuthorization(alice, bob, address(size), Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        assertTrue(!sizeFactory.isAuthorizedOnThisMarket(bob, alice, Action.SELL_CREDIT_MARKET));
        vm.prank(address(size));
        assertTrue(sizeFactory.isAuthorizedOnThisMarket(bob, alice, Action.SELL_CREDIT_MARKET));
    }
}
