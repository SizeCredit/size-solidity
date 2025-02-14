// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {Authorization} from "@src/libraries/actions/v1.7/Authorization.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {SetAuthorizationOnBehalfOfParams, SetAuthorizationParams} from "@src/libraries/actions/v1.7/Authorization.sol";

contract AuthorizationSetAuthorizationTest is BaseTest {
    function test_AuthorizationSetAuthorization_setAuthorization() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(ISize.sellCreditMarket.selector));

        assertTrue(size.isAuthorized(alice, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(alice, alice, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(alice, candy, ISize.sellCreditMarket.selector));

        assertTrue(!size.isAuthorized(bob, alice, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(bob, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(bob, candy, ISize.sellCreditMarket.selector));

        assertTrue(!size.isAuthorized(candy, alice, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(candy, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(candy, candy, ISize.sellCreditMarket.selector));
    }

    function test_AuthorizationSetAuthorization_setAuthorizationOnBehalfOf() public {
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(ISizeV1_7.setAuthorization.selector));

        bytes4[] memory actions = new bytes4[](2);
        actions[0] = ISize.sellCreditMarket.selector;
        actions[1] = ISizeV1_7.setAuthorization.selector;

        vm.prank(bob);
        size.setAuthorizationOnBehalfOf(
            SetAuthorizationOnBehalfOfParams({
                params: SetAuthorizationParams({operator: bob, actionsBitmap: Authorization.getActionsBitmap(actions)}),
                onBehalfOf: alice
            })
        );

        vm.prank(bob);
        size.setAuthorizationOnBehalfOf(
            SetAuthorizationOnBehalfOfParams({
                params: SetAuthorizationParams({operator: candy, actionsBitmap: Authorization.getActionsBitmap(actions)}),
                onBehalfOf: alice
            })
        );

        assertTrue(size.isAuthorized(alice, bob, ISize.sellCreditMarket.selector));
        assertTrue(size.isAuthorized(alice, candy, ISize.sellCreditMarket.selector));
        assertTrue(size.isAuthorized(alice, bob, ISizeV1_7.setAuthorization.selector));
        assertTrue(size.isAuthorized(alice, candy, ISizeV1_7.setAuthorization.selector));
    }

    function test_AuthorizationSetAuthorization_validation() public {
        vm.expectRevert(
            abi.encodeWithSelector(Errors.UNAUTHORIZED_ACTION.selector, alice, bob, ISizeV1_7.setAuthorization.selector)
        );
        vm.prank(alice);
        size.setAuthorizationOnBehalfOf(
            SetAuthorizationOnBehalfOfParams({
                params: SetAuthorizationParams({
                    operator: alice,
                    actionsBitmap: Authorization.getActionsBitmap(ISize.sellCreditMarket.selector)
                }),
                onBehalfOf: bob
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.NULL_ADDRESS.selector));
        vm.prank(alice);
        size.setAuthorization(
            SetAuthorizationParams({
                operator: address(0),
                actionsBitmap: Authorization.getActionsBitmap(ISize.sellCreditMarket.selector)
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTIONS_BITMAP.selector, type(uint256).max));
        vm.prank(alice);
        size.setAuthorization(SetAuthorizationParams({operator: bob, actionsBitmap: type(uint256).max}));

        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_ACTION.selector, bytes4(0)));
        Authorization.getActionsBitmap(bytes4(0));
    }
}
