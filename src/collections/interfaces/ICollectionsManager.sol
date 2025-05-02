// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ICollectionsManager
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManager {
    // curator
    function createColletion() external returns (uint256 collectionId);
    function transferCollection(uint256 collectionId, address newCurator) external;
    function addToCollection(uint256 collectionId, ISize market) external;
    function removeMarketFromCollection(uint256 collectionId, ISize market) external;
    function addRateProvidersToMarket(uint256 collectionId, ISize market, address[] memory rateProviders) external;
    function removeRateProvidersFromMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;
    function setCollectionBounds(
        uint256 collectionId,
        uint256 minAPR,
        uint256 maxAPR,
        uint256 minTenor,
        uint256 maxTenor
    ) external;

    // user
    function subscribeToCollection(uint256 collectionId) external;
    function unsubscribeFromCollection(uint256 collectionId) external;
    function optOutFromCollectionMarket(uint256 collectionId, ISize market) external;
    function optInFromCollectionMarket(uint256 collectionId, ISize market) external;

    // view
    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool);
    function isCopyingRateProvider(address user, address rateProvider) external view returns (bool);
    function isOptedOutFromCollectionMarket(address user, uint256 collectionId, ISize market)
        external
        view
        returns (bool);
    function getCollections(address user) external view returns (uint256[] collectionIds);
    function getCollectionBounds(uint256 collectionId)
        external
        view
        returns (uint256 minAPR, uint256 maxAPR, uint256 minTenor, uint256 maxTenor);
    function getLoanOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256); // user-defined lend curve
    function getBorrowOfferAPR(address user, ISize market, uint256 tenor) external view returns (uint256); // user-defined borrow curve
    function getLoanOfferAPR(address user, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256); // RP lend curve
    function getBorrowOfferAPR(address user, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256); // RP borrow curve
}
