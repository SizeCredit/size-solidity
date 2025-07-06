// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IAToken} from "@aave/interfaces/IAToken.sol";
import {UserView} from "@src/market/SizeView.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {Errors} from "@src/market/libraries/Errors.sol";

import {Action, Authorization} from "@src/factory/libraries/Authorization.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract AuthorizationManageCollectionSubscriptionsTest is BaseTest {
    uint256 private collectionId;

    function setUp() public override {
        super.setUp();
        collectionId = _createCollection(james);
    }

    function test_AuthorizationManageCollectionSubscriptions_subscribeToCollectionsOnBehalfOf() public {
        _setAuthorization(alice, candy, Authorization.getActionsBitmap(Action.MANAGE_COLLECTION_SUBSCRIPTIONS));

        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;

        vm.prank(candy);
        sizeFactory.subscribeToCollectionsOnBehalfOf(collectionIds, alice);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(alice, collectionId), true);

        vm.prank(candy);
        sizeFactory.unsubscribeFromCollectionsOnBehalfOf(collectionIds, alice);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(alice, collectionId), false);
    }

    function test_AuthorizationManageCollectionSubscriptions_validation() public {
        uint256[] memory collectionIds = new uint256[](1);
        collectionIds[0] = collectionId;

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.MANAGE_COLLECTION_SUBSCRIPTIONS
            )
        );
        vm.prank(alice);
        sizeFactory.subscribeToCollectionsOnBehalfOf(collectionIds, bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.UNAUTHORIZED_ACTION.selector, alice, bob, Action.MANAGE_COLLECTION_SUBSCRIPTIONS
            )
        );
        vm.prank(alice);
        sizeFactory.unsubscribeFromCollectionsOnBehalfOf(collectionIds, bob);
    }
}
