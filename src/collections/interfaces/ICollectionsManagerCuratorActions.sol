// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrder} from "@src/market/libraries/OfferLibrary.sol";
/// @title ICollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)

interface ICollectionsManagerCuratorActions {
    /// @dev Mints a ERC721EnumerableUpgradeable NFT collection to the curator. Can be used to transfer ownership of the collection to another curator.
    function createCollection() external returns (uint256 collectionId);
    // TODO pass boundaries both for borrow and loan offers
    function addMarketsToCollection(
        uint256 collectionId,
        ISize[] memory markets,
        CopyLimitOrder[] memory copyLimitOrders
    ) external;

    /// @dev The `delete` keyword will set the `exists` flag to false
    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets) external;

    function addRateProvidersToCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;

    function removeRateProvidersFromCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;
}
