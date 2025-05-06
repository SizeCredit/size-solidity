// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrder} from "@src/market/libraries/OfferLibrary.sol";

/// @title ICollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerView {
    /// @notice Check if a collection ID is valid
    /// @param collectionId The collection ID to check
    /// @return True if the collection ID is valid, false otherwise
    /// @dev Should not revert
    function isValidCollectionId(uint256 collectionId) external view returns (bool);

    /// @notice Check if a user is subscribed to a collection
    /// @param user The user to check
    /// @param collectionId The collection ID to check
    /// @return True if the user is subscribed to the collection, false otherwise
    /// @dev Should not revert
    function isSubscribedToCollection(address user, uint256 collectionId) external view returns (bool);

    /// @notice Check if a collection contains a market
    /// @param collectionId The collection ID to check
    /// @param market The market to check
    /// @return True if the collection contains the market, false otherwise
    /// @dev Should not revert
    function collectionContainsMarket(uint256 collectionId, ISize market) external view returns (bool);

    /// @notice Check if a user is copying a collection rate provider for a market
    /// @param user The user to check
    /// @param collectionId The collection ID to check
    /// @param rateProvider The rate provider to check
    /// @param market The market to check
    /// @return True if the user is copying the collection rate provider for the market, false otherwise
    /// @dev Should not revert
    function isCopyingCollectionRateProviderForMarket(
        address user,
        uint256 collectionId,
        address rateProvider,
        ISize market
    ) external view returns (bool);

    function getSubscribedCollections(address user) external view returns (uint256[] memory collectionIds);

    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr);

    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr);
}
