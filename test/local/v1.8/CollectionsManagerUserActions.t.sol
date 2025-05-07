// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {BaseTest} from "@test/BaseTest.sol";

contract CollectionsManagerUserActionsTest is BaseTest {
    function test_CollectionsManagerUserActions_subscribeToCollection() public {
        uint256 collectionId = _createCollection(alice);

        _subscribeToCollection(bob, collectionId);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(bob, collectionId), true);
    }

    function test_CollectionsManagerUserActions_unsubscribeFromCollection() public {
        uint256 collectionId = _createCollection(alice);

        _subscribeToCollection(bob, collectionId);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(bob, collectionId), true);

        _unsubscribeFromCollection(bob, collectionId);

        assertEq(sizeFactory.collectionsManager().isSubscribedToCollection(bob, collectionId), false);
    }

    function test_CollectionsManagerUserActions_getSubscribedCollections() public {
        uint256 collectionId = _createCollection(alice);
        uint256 collectionId2 = _createCollection(bob);

        _subscribeToCollection(candy, collectionId);
        _subscribeToCollection(candy, collectionId2);

        uint256[] memory collectionIds = collectionsManager.getSubscribedCollections(candy);
        assertEq(collectionIds.length, 2);
        assertEq(collectionIds[0], collectionId);
        assertEq(collectionIds[1], collectionId2);
    }
}
