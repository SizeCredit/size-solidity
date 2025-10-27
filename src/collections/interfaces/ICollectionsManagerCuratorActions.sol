// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ICollectionsManagerCuratorActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerCuratorActions {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event MarketAddedToCollection(uint256 indexed collectionId, address indexed market);
    // deprecated in v1.8.1
    // CopyLimitOrderConfig copyLoanOfferConfig,
    // CopyLimitOrderConfig copyBorrowOfferConfig

    event MarketRemovedFromCollection(uint256 indexed collectionId, address indexed market);
    event RateProviderAddedToMarket(uint256 indexed collectionId, address indexed market, address indexed rateProvider);
    event RateProviderRemovedFromMarket(
        uint256 indexed collectionId, address indexed market, address indexed rateProvider
    );

    /*//////////////////////////////////////////////////////////////
                            ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new collection
    /// @return collectionId The collection ID
    /// @dev Mints a ERC721EnumerableUpgradeable NFT collection to the curator. Can be used to transfer ownership of the collection to another curator.
    function createCollection() external returns (uint256 collectionId);

    /// @notice Adds markets to a collection
    /// @param collectionId The collection ID
    /// @param markets The markets to add
    /// @dev By default, the collection market configs are set to "full", ie, the rate providers limit orders are fully copied without alterations
    function addMarketsToCollection(uint256 collectionId, ISize[] memory markets) external;

    /// @notice Sets the collection market configs
    /// @param collectionId The collection ID
    /// @param markets The markets to set the configs for
    /// @param copyLoanOfferConfigs The copy limit order parameters for loan offers
    /// @param copyBorrowOfferConfigs The copy limit order parameters for borrow offers
    /// @dev This function has the same effect as calling `addMarketsToCollection` but with a custom config for each market
    /// @dev Removed in v1.8.1
    // function setCollectionMarketConfigs(
    //     uint256 collectionId,
    //     ISize[] memory markets,
    //     CopyLimitOrderConfig[] memory copyLoanOfferConfigs,
    //     CopyLimitOrderConfig[] memory copyBorrowOfferConfigs
    // ) external;

    /// @notice Removes markets from a collection
    /// @param collectionId The collection ID
    /// @param markets The markets to remove
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
