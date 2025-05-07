// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CollectionsManagerCuratorActions} from "@src/collections/actions/CollectionsManagerCuratorActions.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract CollectionsManagerCuratorActionsTest is BaseTest {
    function test_CollectionsManagerCuratorActions_createCollection() public {
        uint256 collectionId = _createCollection(alice);
        assertEq(collectionsManager.isValidCollectionId(collectionId), true);
        assertEq(collectionsManager.ownerOf(collectionId), alice);
    }

    function test_CollectionsManagerCuratorActions_transfer_collection() public {
        uint256 collectionId = _createCollection(alice);
        assertEq(collectionsManager.ownerOf(collectionId), alice);

        vm.prank(alice);
        collectionsManager.safeTransferFrom(alice, bob, collectionId);
        assertEq(collectionsManager.ownerOf(collectionId), bob);
    }

    function test_CollectionsManagerCuratorActions_addMarketsToCollection_not_curator() public {
        uint256 collectionId = _createCollection(alice);

        CopyLimitOrderConfig[] memory fullCopies = new CopyLimitOrderConfig[](1);
        fullCopies[0] = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        ISize[] memory markets = new ISize[](1);
        markets[0] = size;

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                CollectionsManagerCuratorActions.CollectionCuratorMismatch.selector, collectionId, alice, bob
            )
        );
        collectionsManager.addMarketsToCollection(collectionId, markets, fullCopies, fullCopies);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), false);
    }

    function test_CollectionsManagerCuratorActions_addMarketsToCollection_curator() public {
        uint256 collectionId = _createCollection(alice);

        CopyLimitOrderConfig[] memory fullCopies = new CopyLimitOrderConfig[](1);
        fullCopies[0] = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        ISize[] memory markets = new ISize[](1);
        markets[0] = size;
        vm.prank(alice);
        collectionsManager.addMarketsToCollection(collectionId, markets, fullCopies, fullCopies);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), true);
    }
}
