// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {CollectionsManagerCuratorActions} from "@src/collections/actions/CollectionsManagerCuratorActions.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract CollectionsManagerCuratorActionsTest is BaseTest {
    function test_CollectionsManagerCuratorActions_createCollection() public {
        uint256 collectionId = _createCollection(alice);
        assertEq(collectionsManager.isValidCollectionId(collectionId), true);
        assertEq(collectionsManager.ownerOf(collectionId), alice);
        assertEq(collectionsManager.tokenURI(collectionId), "https://size.credit/collections/1/1");
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
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, bob, collectionId));
        collectionsManager.addMarketsToCollection(collectionId, markets, fullCopies, fullCopies);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), false);
    }

    function test_CollectionsManagerCuratorActions_addMarketsToCollection_approved() public {
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
        collectionsManager.approve(bob, collectionId);

        vm.prank(bob);
        collectionsManager.addMarketsToCollection(collectionId, markets, fullCopies, fullCopies);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), true);

        assertEq(collectionsManager.collectionContainsMarket(type(uint256).max, size), false);
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

    function test_CollectionsManagerCuratorActions_removeMarketsFromCollection() public {
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

        vm.prank(alice);
        collectionsManager.removeMarketsFromCollection(collectionId, markets);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), false);
    }

    function test_CollectionsManagerCuratorActions_addRateProvidersToCollectionMarket() public {
        uint256 collectionId = _createCollection(alice);

        vm.expectRevert(
            abi.encodeWithSelector(CollectionsManagerBase.MarketNotInCollection.selector, collectionId, address(size))
        );
        collectionsManager.getCollectionMarketRateProviders(collectionId, size);

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

        address[] memory rateProviders = new address[](2);
        rateProviders[0] = bob;
        rateProviders[1] = candy;

        vm.prank(alice);
        collectionsManager.addRateProvidersToCollectionMarket(collectionId, size, rateProviders);

        address[] memory ans = collectionsManager.getCollectionMarketRateProviders(collectionId, size);
        assertEq(ans.length, 2);
        assertEq(ans[0], bob);
        assertEq(ans[1], candy);

        vm.expectRevert(abi.encodeWithSelector(CollectionsManagerBase.InvalidCollectionId.selector, collectionId + 1));
        collectionsManager.getCollectionMarketRateProviders(collectionId + 1, size);
    }

    function test_CollectionsManagerCuratorActions_removeRateProvidersFromCollectionMarket() public {
        bytes[] memory datas = new bytes[](3);
        uint256 collectionId = 0;

        datas[0] = abi.encodeCall(CollectionsManagerCuratorActions.createCollection, ());
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
        datas[1] = abi.encodeCall(
            CollectionsManagerCuratorActions.addMarketsToCollection, (collectionId, markets, fullCopies, fullCopies)
        );

        address[] memory rateProviders = new address[](2);
        rateProviders[0] = bob;
        rateProviders[1] = candy;

        datas[2] = abi.encodeCall(
            CollectionsManagerCuratorActions.addRateProvidersToCollectionMarket, (collectionId, size, rateProviders)
        );

        vm.prank(alice);
        collectionsManager.multicall(datas);

        address[] memory ans = collectionsManager.getCollectionMarketRateProviders(collectionId, size);
        assertEq(ans.length, 2);
        assertEq(ans[0], bob);
        assertEq(ans[1], candy);

        rateProviders = new address[](1);
        rateProviders[0] = bob;

        vm.prank(alice);
        collectionsManager.removeRateProvidersFromCollectionMarket(collectionId, size, rateProviders);

        ans = collectionsManager.getCollectionMarketRateProviders(collectionId, size);
        assertEq(ans.length, 1);
        assertEq(ans[0], candy);
    }
}
