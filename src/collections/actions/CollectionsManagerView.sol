// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CollectionsManagerBase} from "@src/collections/CollectionsManagerBase.sol";
import {ICollectionsManagerView} from "@src/collections/interfaces/ICollectionsManagerView.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title CollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerView}.
abstract contract CollectionsManagerView is ICollectionsManagerView, CollectionsManagerBase {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    function isValidCollectionId(uint256 collectionId) public view returns (bool) {
        return collectionId > 0 && collectionId <= collectionIdCounter;
    }

    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool) {
        return userToCollectionIds[user].contains(collectionId);
    }

    function isCopyingRateProvider(address user, address rateProvider, ISize market) external view returns (bool) {
        // TODO
    }

    function getSubscribedCollections(address user) external view returns (uint256[] memory collectionIds) {
        return userToCollectionIds[user].values();
    }

    function getLoanOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256) {
        // TODO
    }

    function getBorrowOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256) {
        // TODO
    }

    function getLoanOfferAPR(address user, address rateProvider, ISize market, uint256 tenor)
        external
        view
        returns (uint256)
    {
        // TODO
    }

    function getBorrowOfferAPR(address user, address rateProvider, ISize market, uint256 tenor)
        external
        view
        returns (uint256)
    {
        // TODO
    }

    /*//////////////////////////////////////////////////////////////
                            COLLECTION VIEW
    //////////////////////////////////////////////////////////////*/

    function getCollectionBounds(uint256 collectionId)
        external
        view
        returns (uint256 minAPR, uint256 maxAPR, uint256 minTenor, uint256 maxTenor)
    {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        minAPR = collections[collectionId].minAPR;
        maxAPR = collections[collectionId].maxAPR;
        minTenor = collections[collectionId].minTenor;
        maxTenor = collections[collectionId].maxTenor;
    }

    function getCollectionCurator(uint256 collectionId) external view returns (address) {
        return collections[collectionId].curator;
    }

    function getCollectionMarkets(uint256 collectionId) external view returns (address[] memory) {
        return collections[collectionId].markets.values();
    }

    function getCollectionMarketRateProviders(uint256 collectionId, ISize market)
        external
        view
        returns (address[] memory)
    {
        return collections[collectionId].marketToRateProviders[market].values();
    }
}
