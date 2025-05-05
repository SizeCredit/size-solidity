// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ICollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerCuratorActions {
    /// @dev Mints a ERC721EnumerableUpgradeable NFT collection to the curator. Can be used to transfer ownership of the collection to another curator.
    function createCollection() external returns (uint256 collectionId);
    function addMarketsToCollection(uint256 collectionId, ISize[] memory markets) external;

    /// @dev The `delete` keyword will set the `exists` flag to false
    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets) external;

    function addRateProvidersToCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;

    function removeRateProvidersFromCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;

    /// @notice Set the bounds for a market in a collection
    /// @dev If the curator does not call this function for a market, no orders will be able to be matched, since by default the bounds are all 0
    function setCollectionMarketBounds(
        uint256 collectionId,
        ISize market,
        uint256 minAPR,
        uint256 maxAPR,
        uint256 minTenor,
        uint256 maxTenor
    ) external;
}
