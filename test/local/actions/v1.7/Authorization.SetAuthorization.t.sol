// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {Action} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationSetAuthorizationTest is BaseTest {
    function test_AuthorizationSetAuthorization_setAuthorization() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(ISize.sellCreditMarket.selector));

        assertTrue(size.isAuthorized(alice, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(alice, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(alice, candy, Action.SELL_CREDIT_MARKET));

        assertTrue(!size.isAuthorized(bob, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(bob, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(bob, candy, Action.SELL_CREDIT_MARKET));

        assertTrue(!size.isAuthorized(candy, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(candy, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(candy, candy, Action.SELL_CREDIT_MARKET));
    }

    function test_AuthorizationSetAuthorization_validation() public {
        address market = address(size);
        vm.expectRevert(
            abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, market, Action.SELL_CREDIT_MARKET)
        );
        vm.prank(alice);
        sizeFactory.setAuthorization(alice, bob, market, Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        vm.prank(alice);
        sizeFactory.setAuthorization(address(0), bob, market, Authorization.getActionsBitmap(Action.SELL_CREDIT_MARKET));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTIONS_BITMAP.selector, type(uint256).max));
        vm.prank(alice);
        sizeFactory.setAuthorization(bob, bob, market, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTION.selector, Action.LAST_ACTION));
        Authorization.getActionsBitmap(Action.LAST_ACTION);
    }
}
