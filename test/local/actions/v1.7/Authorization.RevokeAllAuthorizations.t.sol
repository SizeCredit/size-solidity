// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";

import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

contract AuthorizationRevokeAllAuthorizationsTest is BaseTest {
    function test_AuthorizationRevokeAllAuthorizations_revokeAllAuthorizations() public {
        Action[] memory actions = new Action[](2);
        actions[0] = Action.SELL_CREDIT_MARKET;
        actions[1] = Action.BUY_CREDIT_MARKET;
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(actions));

        assertTrue(size.isAuthorized(alice, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(size.isAuthorized(alice, bob, Action.BUY_CREDIT_MARKET));

        actions[0] = Action.SELL_CREDIT_LIMIT;
        actions[1] = Action.BUY_CREDIT_LIMIT;
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(actions));

        assertTrue(size.isAuthorized(alice, candy, Action.SELL_CREDIT_LIMIT));
        assertTrue(size.isAuthorized(alice, candy, Action.BUY_CREDIT_LIMIT));

        vm.prank(alice);
        size.revokeAllAuthorizations();

        assertTrue(!size.isAuthorized(alice, bob, Action.SELL_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(alice, bob, Action.BUY_CREDIT_MARKET));
        assertTrue(!size.isAuthorized(alice, candy, Action.SELL_CREDIT_LIMIT));
        assertTrue(!size.isAuthorized(alice, candy, Action.BUY_CREDIT_LIMIT));
    }
}
