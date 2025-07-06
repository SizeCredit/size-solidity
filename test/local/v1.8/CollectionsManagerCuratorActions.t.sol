// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {CollectionsManagerCuratorActions} from "@src/collections/actions/CollectionsManagerCuratorActions.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Errors} from "@src/market/libraries/Errors.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
import {BaseTest} from "@test/BaseTest.sol";

contract CollectionsManagerCuratorActionsTest is BaseTest {
    function test_CollectionsManagerCuratorActions_createCollection() public {
        uint256 collectionId = _createCollection(alice);
        assertEq(collectionsManager.isValidCollectionId(collectionId), true);
        assertEq(collectionsManager.ownerOf(collectionId), alice);
        assertEq(collectionsManager.tokenURI(collectionId), "https://api.size.credit/collections/31337/0");
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

        ISize[] memory markets = new ISize[](1);
        markets[0] = size;

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, bob, collectionId));
        collectionsManager.addMarketsToCollection(collectionId, markets);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), false);
    }

    function test_CollectionsManagerCuratorActions_addMarketsToCollection_approved() public {
        uint256 collectionId = _createCollection(alice);

        ISize[] memory markets = new ISize[](1);
        markets[0] = size;

        vm.prank(alice);
        collectionsManager.approve(bob, collectionId);

        vm.prank(bob);
        collectionsManager.addMarketsToCollection(collectionId, markets);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), true);

        assertEq(collectionsManager.collectionContainsMarket(type(uint256).max, size), false);
    }

    function test_CollectionsManagerCuratorActions_addMarketsToCollection_input_validation() public {
        uint256 collectionId = _createCollection(alice);

        CopyLimitOrderConfig[] memory copyLoanOfferConfigs = new CopyLimitOrderConfig[](1);
        copyLoanOfferConfigs[0] = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        CopyLimitOrderConfig[] memory copyBorrowOfferConfigs = new CopyLimitOrderConfig[](1);
        copyBorrowOfferConfigs[0] = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });
        ISize[] memory markets = new ISize[](2);
        markets[0] = size;

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.ARRAY_LENGTHS_MISMATCH.selector));
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );

        markets = new ISize[](1);
        markets[0] = ISize(address(0));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_MARKET.selector, address(0)));
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );

        markets[0] = size;

        copyLoanOfferConfigs[0].minTenor = 4;
        copyLoanOfferConfigs[0].maxTenor = 3;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TENOR_RANGE.selector, 4, 3));
        vm.prank(alice);
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );

        copyLoanOfferConfigs[0].minTenor = 0;
        copyLoanOfferConfigs[0].maxTenor = type(uint256).max;
        copyLoanOfferConfigs[0].minAPR = 7;
        copyLoanOfferConfigs[0].maxAPR = 5;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_APR_RANGE.selector, 7, 5));
        vm.prank(alice);
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );

        copyLoanOfferConfigs[0].minAPR = 0;
        copyLoanOfferConfigs[0].maxAPR = type(uint256).max;
        copyBorrowOfferConfigs[0].minTenor = 4;
        copyBorrowOfferConfigs[0].maxTenor = 3;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_TENOR_RANGE.selector, 4, 3));
        vm.prank(alice);
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );

        copyBorrowOfferConfigs[0].minTenor = 0;
        copyBorrowOfferConfigs[0].maxTenor = type(uint256).max;
        copyBorrowOfferConfigs[0].minAPR = 7;
        copyBorrowOfferConfigs[0].maxAPR = 5;
        vm.expectRevert(abi.encodeWithSelector(Errors.INVALID_APR_RANGE.selector, 7, 5));
        vm.prank(alice);
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );

        copyBorrowOfferConfigs[0].minTenor = 15 days;
        copyBorrowOfferConfigs[0].maxTenor = 45 days;
        copyBorrowOfferConfigs[0].minAPR = 0.06e18;
        copyBorrowOfferConfigs[0].maxAPR = 0.08e18;
        copyLoanOfferConfigs[0].minTenor = 10 days;
        copyLoanOfferConfigs[0].maxTenor = 30 days;
        copyLoanOfferConfigs[0].minAPR = 0.03e18;
        copyLoanOfferConfigs[0].maxAPR = 0.05e18;
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.INVALID_OFFER_CONFIGS.selector,
                15 days,
                45 days,
                0.06e18,
                0.08e18,
                10 days,
                30 days,
                0.03e18,
                0.05e18
            )
        );
        vm.prank(alice);
        collectionsManager.setCollectionMarketConfigs(
            collectionId, markets, copyLoanOfferConfigs, copyBorrowOfferConfigs
        );
    }

    function test_CollectionsManagerCuratorActions_addMarketsToCollection_curator() public {
        uint256 collectionId = _createCollection(alice);

        ISize[] memory markets = new ISize[](1);
        markets[0] = size;
        vm.prank(alice);
        collectionsManager.addMarketsToCollection(collectionId, markets);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), true);
    }

    function test_CollectionsManagerCuratorActions_removeMarketsFromCollection() public {
        uint256 collectionId = _createCollection(alice);

        ISize[] memory markets = new ISize[](1);
        markets[0] = size;
        vm.prank(alice);
        collectionsManager.addMarketsToCollection(collectionId, markets);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), true);

        vm.prank(alice);
        collectionsManager.removeMarketsFromCollection(collectionId, markets);

        assertEq(collectionsManager.collectionContainsMarket(collectionId, size), false);
    }

    function test_CollectionsManagerCuratorActions_addRateProvidersToCollectionMarket() public {
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

        address[] memory rateProviders = new address[](2);
        rateProviders[0] = bob;
        rateProviders[1] = candy;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(CollectionsManagerBase.MarketNotInCollection.selector, collectionId, address(size))
        );
        collectionsManager.addRateProvidersToCollectionMarket(collectionId, size, rateProviders);

        vm.expectRevert(
            abi.encodeWithSelector(CollectionsManagerBase.MarketNotInCollection.selector, collectionId, address(size))
        );
        collectionsManager.getCollectionMarketRateProviders(collectionId, size);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(CollectionsManagerBase.MarketNotInCollection.selector, collectionId, address(size))
        );
        collectionsManager.removeRateProvidersFromCollectionMarket(collectionId, size, rateProviders);

        vm.prank(alice);
        collectionsManager.addMarketsToCollection(collectionId, markets);

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
        ISize[] memory markets = new ISize[](1);
        markets[0] = size;
        datas[1] = abi.encodeCall(CollectionsManagerCuratorActions.addMarketsToCollection, (collectionId, markets));

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
