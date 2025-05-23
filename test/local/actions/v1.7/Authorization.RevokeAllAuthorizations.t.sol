// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/market/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {RESERVED_ID} from "@src/market/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/market/libraries/Math.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationRevokeAllAuthorizationsTest is BaseTest {
    function test_AuthorizationRevokeAllAuthorizations_revokeAllAuthorizations() public {
        Action[] memory actions = new Action[](2);
        actions[0] = Action.SELL_CREDIT_MARKET;
        actions[1] = Action.BUY_CREDIT_MARKET;
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(actions));

        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.BUY_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorizedAll(bob, alice, Authorization.getActionsBitmap(actions)));
        assertTrue(!sizeFactory.isAuthorizedAll(candy, alice, Authorization.getActionsBitmap(actions)));
        assertTrue(sizeFactory.isAuthorizedAll(candy, candy, Authorization.getActionsBitmap(actions)));

        actions[0] = Action.SELL_CREDIT_LIMIT;
        actions[1] = Action.BUY_CREDIT_LIMIT;
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(actions));
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(actions));

        assertTrue(!sizeFactory.isAuthorized(bob, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(bob, alice, Action.BUY_CREDIT_MARKET));
        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.SELL_CREDIT_LIMIT));
        assertTrue(sizeFactory.isAuthorized(bob, alice, Action.BUY_CREDIT_LIMIT));
        assertTrue(sizeFactory.isAuthorizedAll(bob, alice, Authorization.getActionsBitmap(actions)));

        assertTrue(sizeFactory.isAuthorized(candy, alice, Action.SELL_CREDIT_LIMIT));
        assertTrue(sizeFactory.isAuthorized(candy, alice, Action.BUY_CREDIT_LIMIT));
        assertTrue(sizeFactory.isAuthorizedAll(candy, alice, Authorization.getActionsBitmap(actions)));

        vm.prank(alice);
        sizeFactory.revokeAllAuthorizations();

        assertTrue(!sizeFactory.isAuthorized(bob, alice, Action.SELL_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(bob, alice, Action.BUY_CREDIT_MARKET));
        assertTrue(!sizeFactory.isAuthorized(candy, alice, Action.SELL_CREDIT_LIMIT));
        assertTrue(!sizeFactory.isAuthorized(candy, alice, Action.BUY_CREDIT_LIMIT));
        assertTrue(!sizeFactory.isAuthorizedAll(bob, alice, Authorization.getActionsBitmap(actions)));
        assertTrue(!sizeFactory.isAuthorizedAll(candy, alice, Authorization.getActionsBitmap(actions)));
    }
}
