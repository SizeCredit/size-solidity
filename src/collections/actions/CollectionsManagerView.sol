// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrder} from "@src/market/libraries/OfferLibrary.sol";

/// @title CollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerView}.
abstract contract CollectionsManagerView is ICollectionsManagerView, CollectionsManagerBase {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @inheritdoc ICollectionsManagerView
    function isValidCollectionId(uint256 collectionId) public view returns (bool) {
        return collectionId < collectionIdCounter;
    }

    /// @inheritdoc ICollectionsManagerView
    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool) {
        return userToCollectionIds[user].contains(collectionId);
    }

    /// @inheritdoc ICollectionsManagerView
    function isCopyingCollectionRateProviderForMarket(
        address user,
        uint256 collectionId,
        address rateProvider,
        ISize market
    ) public view returns (bool) {
        if (!isValidCollectionId(collectionId)) {
            return false;
        }
        if (!userToCollectionIds[user].contains(collectionId)) {
            return false;
        }
        if (!collections[collectionId][market].exists) {
            return false;
        }
        return collections[collectionId][market].rateProviders.contains(rateProvider);
    }

    /// @inheritdoc ICollectionsManagerView
    function getSubscribedCollections(address user) external view returns (uint256[] memory collectionIds) {
        return userToCollectionIds[user].values();
    }

    /*//////////////////////////////////////////////////////////////
                            APR VIEW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICollectionsManagerView
    function getLoanOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256) {
        return market.getLoanOfferAPR(user, tenor);
    }

    /// @inheritdoc ICollectionsManagerView
    function getBorrowOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256) {
        return market.getBorrowOfferAPR(user, tenor);
    }

    function getLoanOfferAPR(address user, uint256 collectionId, address rateProvider, ISize market, uint256 tenor)
        external
        view
        returns (uint256)
    {
        // TODO
        if (!isCopyingCollectionRateProviderForMarket(user, collectionId, rateProvider, market)) {
            return type(uint256).max;
        }
        return market.getLoanOfferAPR(rateProvider, tenor);
    }

    function getBorrowOfferAPR(address user, uint256 collectionId, address rateProvider, ISize market, uint256 tenor)
        external
        view
        returns (uint256)
    {
        // TODO
        if (!isCopyingCollectionRateProviderForMarket(user, collectionId, rateProvider, market)) {
            return 0;
        }
        return market.getBorrowOfferAPR(rateProvider, tenor);
    }

    /*//////////////////////////////////////////////////////////////
                            COLLECTION VIEW
    //////////////////////////////////////////////////////////////*/

    function getCollectionMarketCopyLimitOrder(uint256 collectionId, ISize market)
        external
        view
        returns (CopyLimitOrder memory)
    {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        if (!collections[collectionId][market].exists) {
            revert MarketNotInCollection(collectionId, address(market));
        }
        return collections[collectionId][market].copyLimitOrder;
    }

    function getCollectionMarketRateProviders(uint256 collectionId, ISize market)
        external
        view
        returns (address[] memory)
    {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        if (!collections[collectionId][market].exists) {
            revert MarketNotInCollection(collectionId, address(market));
        }
        return collections[collectionId][market].rateProviders.values();
    }
}
