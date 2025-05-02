// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Collection, CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";

import {ICollectionsManagerCuratorActions} from "@src/collections/interfaces/ICollectionsManagerCuratorActions.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

/// @title CollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerCuratorActions}.
abstract contract CollectionsManagerCuratorActions is ICollectionsManagerCuratorActions, CollectionsManagerBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event CollectionCreated(uint256 collectionId, address curator);
    event CollectionTransferred(uint256 collectionId, address oldCurator, address newCurator);
    event MarketAddedToCollection(uint256 collectionId, address market);
    event MarketRemovedFromCollection(uint256 collectionId, address market);
    event RateProviderAddedToMarket(uint256 collectionId, address market, address rateProvider);
    event RateProviderRemovedFromMarket(uint256 collectionId, address market, address rateProvider);
    event CollectionBoundsSet(uint256 collectionId, uint256 minAPR, uint256 maxAPR, uint256 minTenor, uint256 maxTenor);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error CollectionCuratorMismatch(uint256 collectionId, address expectedCurator, address curator);
    error MarketNotInCollection(uint256 collectionId, address market);
    error RateProviderNotInMarket(uint256 collectionId, address market, address rateProvider);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyCollectionCurator(uint256 collectionId) {
        if (collections[collectionId].curator != msg.sender) {
            revert CollectionCuratorMismatch(collectionId, collections[collectionId].curator, msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CURATOR ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollectionsManagerCuratorActions
    function createCollection() external returns (uint256 collectionId) {
        collectionId = collectionIdCounter++;

        Collection storage collection = collections[collectionIdCounter];
        collection.curator = msg.sender;
        collection.minAPR = 0;
        collection.maxAPR = type(uint256).max;
        collection.minTenor = 0;
        collection.maxTenor = type(uint256).max;

        emit CollectionCreated(collectionIdCounter, msg.sender);
    }

    function transferCollection(uint256 collectionId, address newCurator)
        external
        onlyCollectionCurator(collectionId)
    {
        Collection storage collection = collections[collectionId];
        collection.curator = newCurator;

        emit CollectionTransferred(collectionId, msg.sender, newCurator);
    }

    function addMarketsToCollection(uint256 collectionId, ISize[] memory markets)
        external
        onlyCollectionCurator(collectionId)
    {
        for (uint256 i = 0; i < markets.length; i++) {
            if (!sizeFactory.isMarket(address(markets[i]))) {
                revert Errors.INVALID_MARKET(address(markets[i]));
            }

            bool added = collections[collectionId].markets.add(address(markets[i]));
            if (added) {
                emit MarketAddedToCollection(collectionId, address(markets[i]));
            }
        }
    }

    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets)
        external
        onlyCollectionCurator(collectionId)
    {
        Collection storage collection = collections[collectionId];
        for (uint256 i = 0; i < markets.length; i++) {
            bool removed = collection.markets.remove(address(markets[i]));
            if (removed) {
                emit MarketRemovedFromCollection(collectionId, address(markets[i]));
            }
        }
    }

    function addRateProvidersToMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external
        onlyCollectionCurator(collectionId)
    {
        if (!collections[collectionId].markets.contains(address(market))) {
            revert MarketNotInCollection(collectionId, address(market));
        }

        for (uint256 i = 0; i < rateProviders.length; i++) {
            bool added = collections[collectionId].marketToRateProviders[market].add(rateProviders[i]);
            if (added) {
                emit RateProviderAddedToMarket(collectionId, address(market), rateProviders[i]);
            }
        }
    }

    function removeRateProvidersFromMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external
        onlyCollectionCurator(collectionId)
    {
        if (!collections[collectionId].markets.contains(address(market))) {
            revert MarketNotInCollection(collectionId, address(market));
        }

        for (uint256 i = 0; i < rateProviders.length; i++) {
            bool removed = collections[collectionId].marketToRateProviders[market].remove(rateProviders[i]);
            if (removed) {
                emit RateProviderRemovedFromMarket(collectionId, address(market), rateProviders[i]);
            }
        }
    }

    function setCollectionBounds(
        uint256 collectionId,
        uint256 minAPR,
        uint256 maxAPR,
        uint256 minTenor,
        uint256 maxTenor
    ) external onlyCollectionCurator(collectionId) {
        if (minAPR > maxAPR) {
            revert Errors.INVALID_APR_RANGE(minAPR, maxAPR);
        }
        if (minTenor > maxTenor) {
            revert Errors.INVALID_TENOR_RANGE(minTenor, maxTenor);
        }

        collections[collectionId].minAPR = minAPR;
        collections[collectionId].maxAPR = maxAPR;
        collections[collectionId].minTenor = minTenor;
        collections[collectionId].maxTenor = maxTenor;

        emit CollectionBoundsSet(collectionId, minAPR, maxAPR, minTenor, maxTenor);
    }
}
