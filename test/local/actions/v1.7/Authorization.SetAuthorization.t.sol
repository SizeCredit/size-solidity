// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/interfaces/ISize.sol";
import {ISizeV1_7} from "@src/interfaces/v1.7/ISizeV1_7.sol";
import {Errors} from "@src/libraries/Errors.sol";

import {RESERVED_ID} from "@src/libraries/LoanLibrary.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {BaseTest, Vars} from "@test/BaseTest.sol";
import {YieldCurveHelper} from "@test/helpers/libraries/YieldCurveHelper.sol";

import {SetAuthorizationOnBehalfOfParams, SetAuthorizationParams} from "@src/libraries/actions/v1.7/Authorization.sol";

contract AuthorizationSetAuthorizationTest is BaseTest {
    function test_AuthorizationSetAuthorization_setAuthorization() public {
        _setAuthorization(alice, bob, ISize.sellCreditMarket.selector, true);

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
        _setAuthorization(alice, bob, ISizeV1_7.setAuthorization.selector, true);

        vm.prank(bob);
        size.setAuthorizationOnBehalfOf(
            SetAuthorizationOnBehalfOfParams({
                params: SetAuthorizationParams({
                    operator: bob,
                    action: ISize.sellCreditMarket.selector,
                    isActionAuthorized: true
                }),
                onBehalfOf: alice
            })
        );

        vm.prank(bob);
        size.setAuthorizationOnBehalfOf(
            SetAuthorizationOnBehalfOfParams({
                params: SetAuthorizationParams({
                    operator: candy,
                    action: ISize.sellCreditMarket.selector,
                    isActionAuthorized: true
                }),
                onBehalfOf: alice
            })
        );

        assertTrue(size.isAuthorized(alice, bob, ISize.sellCreditMarket.selector));
        assertTrue(size.isAuthorized(alice, candy, ISize.sellCreditMarket.selector));
    }
}
