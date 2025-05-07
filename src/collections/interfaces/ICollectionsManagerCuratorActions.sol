// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";
/// @title ICollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)

interface ICollectionsManagerCuratorActions {
    /// @notice Creates a new collection
    /// @return collectionId The collection ID
    /// @dev Mints a ERC721EnumerableUpgradeable NFT collection to the curator. Can be used to transfer ownership of the collection to another curator.
    function createCollection() external returns (uint256 collectionId);

    /// @notice Adds markets to a collection
    /// @param collectionId The collection ID
    /// @param markets The markets to add
    /// @param copyLoanOfferConfigs The copy limit order parameters for loan offers
    /// @param copyBorrowOfferConfigs The copy limit order parameters for borrow offers
    function addMarketsToCollection(
        uint256 collectionId,
        ISize[] memory markets,
        CopyLimitOrderConfig[] memory copyLoanOfferConfigs,
        CopyLimitOrderConfig[] memory copyBorrowOfferConfigs
    ) external;

    /// @notice Removes markets from a collection
    /// @param collectionId The collection ID
    /// @param markets The markets to remove
    /// @dev The `delete` keyword will set the `exists` flag to false. This DOES NOT remove all rate providers from markets in the collection.
    ///        If a subsequent `addMarketsToCollection` is called, previously added `rateProviders` will still be set.
    function removeMarketsFromCollection(uint256 collectionId, ISize[] memory markets) external;

    /// @notice Adds rate providers to a collection market
    /// @param collectionId The collection ID
    /// @param market The market to add the rate providers to
    /// @param rateProviders The rate providers to add
    function addRateProvidersToCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;

    /// @notice Removes rate providers from a collection market
    /// @param collectionId The collection ID
    /// @param market The market to remove the rate providers from
    /// @param rateProviders The rate providers to remove
    function removeRateProvidersFromCollectionMarket(uint256 collectionId, ISize market, address[] memory rateProviders)
        external;
}
