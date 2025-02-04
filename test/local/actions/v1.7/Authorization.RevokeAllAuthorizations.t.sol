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

contract AuthorizationRevokeAllAuthorizationsTest is BaseTest {
    function test_AuthorizationRevokeAllAuthorizations_revokeAllAuthorizations() public {
        bytes4[] memory actions = new bytes4[](2);
        actions[0] = ISize.sellCreditMarket.selector;
        actions[1] = ISize.buyCreditMarket.selector;
        _setAuthorization(alice, bob, Authorization.getActionsBitmap(actions));

        assertTrue(size.isAuthorized(alice, bob, ISize.sellCreditMarket.selector));
        assertTrue(size.isAuthorized(alice, bob, ISize.buyCreditMarket.selector));

        actions[0] = ISize.sellCreditLimit.selector;
        actions[1] = ISize.buyCreditLimit.selector;
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(actions));

        assertTrue(size.isAuthorized(alice, candy, ISize.sellCreditLimit.selector));
        assertTrue(size.isAuthorized(alice, candy, ISize.buyCreditLimit.selector));

        vm.prank(alice);
        size.revokeAllAuthorizations();

        assertTrue(!size.isAuthorized(alice, bob, ISize.sellCreditMarket.selector));
        assertTrue(!size.isAuthorized(alice, bob, ISize.buyCreditMarket.selector));
        assertTrue(!size.isAuthorized(alice, candy, ISize.sellCreditLimit.selector));
        assertTrue(!size.isAuthorized(alice, candy, ISize.buyCreditLimit.selector));
    }
}
