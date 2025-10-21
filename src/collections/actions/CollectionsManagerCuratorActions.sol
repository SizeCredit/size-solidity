// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CopyLimitOrderConfig, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";

import {ICollectionsManagerCuratorActions} from "@src/collections/interfaces/ICollectionsManagerCuratorActions.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

/// @title CollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerCuratorActions}.
abstract contract CollectionsManagerCuratorActions is
    ICollectionsManagerCuratorActions,
    CollectionsManagerBase,
    ERC721EnumerableUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyCollectionCuratorAuthorized(uint256 collectionId) {
        _checkAuthorized(ownerOf(collectionId), msg.sender, collectionId);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CURATOR ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollectionsManagerCuratorActions
    function createCollection() external returns (uint256 collectionId) {
        collectionId = collectionIdCounter++;
        _safeMint(msg.sender, collectionId);
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function addMarketsToCollection(uint256 collectionId, ISize[] memory markets)
        external
        onlyCollectionCuratorAuthorized(collectionId)
    {
        // slither-disable-start calls-loop
        for (uint256 i = 0; i < markets.length; i++) {
            if (!sizeFactory.isMarket(address(markets[i]))) {
                revert Errors.INVALID_MARKET(address(markets[i]));
            }
            if (PausableUpgradeable(address(markets[i])).paused()) {
                revert Errors.PAUSED_MARKET(address(markets[i]));
            }
            collections[collectionId][markets[i]].initialized = true;

            emit MarketAddedToCollection(collectionId, address(markets[i]));
        }
        // slither-disable-end calls-loop
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets)
        external
        onlyCollectionCuratorAuthorized(collectionId)
    {
        for (uint256 i = 0; i < markets.length; i++) {
            address[] memory rateProviders = collections[collectionId][markets[i]].rateProviders.values();
            removeRateProvidersFromCollectionMarket(collectionId, markets[i], rateProviders);
            delete collections[collectionId][markets[i]];
            emit MarketRemovedFromCollection(collectionId, address(markets[i]));
        }
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function addRateProvidersToCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external
        onlyCollectionCuratorAuthorized(collectionId)
    {
        if (!collections[collectionId][market].initialized) {
            revert MarketNotInCollection(collectionId, address(market));
        }

        for (uint256 i = 0; i < rateProviders.length; i++) {
            bool added = collections[collectionId][market].rateProviders.add(rateProviders[i]);
            if (added) {
                emit RateProviderAddedToMarket(collectionId, address(market), rateProviders[i]);
            }
        }
    }

    /// @inheritdoc ICollectionsManagerCuratorActions
    function removeRateProvidersFromCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        public
        onlyCollectionCuratorAuthorized(collectionId)
    {
        if (!collections[collectionId][market].initialized) {
            revert MarketNotInCollection(collectionId, address(market));
        }

        for (uint256 i = 0; i < rateProviders.length; i++) {
            bool removed = collections[collectionId][market].rateProviders.remove(rateProviders[i]);
            if (removed) {
                emit RateProviderRemovedFromMarket(collectionId, address(market), rateProviders[i]);
            }
        }
    }
}
