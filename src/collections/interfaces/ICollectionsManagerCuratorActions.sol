// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ICollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerCuratorActions {
    function createCollection() external returns (uint256 collectionId);
    function transferCollection(uint256 collectionId, address newCurator) external;
    function addMarketsToCollection(uint256 collectionId, ISize[] memory markets) external;
    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets) external;
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
}
