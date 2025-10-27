// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";

/// @title ICollectionsManagerView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerView {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCollectionMarketRateProvider(uint256 collectionId, address market, address rateProvider);
    error InvalidTenor(uint256 tenor, uint256 minTenor, uint256 maxTenor);

    /*//////////////////////////////////////////////////////////////
                            VIEW
    //////////////////////////////////////////////////////////////*/

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

    /// @notice Get the rate providers for a collection market
    /// @param collectionId The collection ID to get the rate providers for
    /// @param market The market to get the rate providers for
    /// @return The rate providers for the collection market
    function getCollectionMarketRateProviders(uint256 collectionId, ISize market)
        external
        view
        returns (address[] memory);

    /// @notice Check if a user is copying a collection market rate provider
    /// @param user The user to check
    /// @param collectionId The collection ID to check
    /// @param market The market to check
    /// @param rateProvider The rate provider to check
    /// @return True if the user is copying the collection market rate provider, false otherwise
    /// @dev Should not revert
    function isCopyingCollectionMarketRateProvider(
        address user,
        uint256 collectionId,
        ISize market,
        address rateProvider
    ) external view returns (bool);

    /// @notice Get the subscribed collections for a user
    /// @param user The user to get the subscribed collections for
    /// @return collectionIds The subscribed collections for the user
    /// @dev Should not revert
    function getSubscribedCollections(address user) external view returns (uint256[] memory collectionIds);

    /// @notice Get the loan offer APR for a user, collection, market, rate provider and tenor
    /// @param user The user to get the loan offer APR for
    /// @param collectionId The collection ID to get the loan offer APR for
    /// @param market The market to get the loan offer APR for
    /// @param rateProvider The rate provider to get the loan offer APR for
    /// @param tenor The tenor to get the loan offer APR for
    /// @return apr The loan offer APR
    /// @dev If collectionId is RESERVED_ID, selects the user-defined yield curve
    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr);

    /// @notice Get the borrow offer APR for a user, collection, market, rate provider and tenor
    /// @param user The user to get the borrow offer APR for
    /// @param collectionId The collection ID to get the borrow offer APR for
    /// @param market The market to get the borrow offer APR for
    /// @param rateProvider The rate provider to get the borrow offer APR for
    /// @param tenor The tenor to get the borrow offer APR for
    /// @return apr The borrow offer APR
    /// @dev If collectionId is RESERVED_ID, selects the user-defined yield curve
    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256 apr);

    /// @notice Check if the borrow APR is lower than the loan offer APRs
    /// @param user The user
    /// @param borrowAPR The borrow APR
    /// @param market The market
    /// @param tenor The tenor
    /// @return isLower True if the borrow APR is lower than the loan offer APRs, false otherwise
    /// @dev Perform this check in O(C * R + 1), where C is the number of subscribed collections, R is the number of rate providers, and 1 is for the user-defined APR check
    ///      Users should be aware that subscribing to too many collections / rate providers may result in market order reverts due to gas limits
    function isBorrowAPRLowerThanLoanOfferAPRs(address user, uint256 borrowAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool);

    /// @notice Check if the loan APR is greater than the borrow offer APRs
    /// @param user The user
    /// @param loanAPR The loan APR
    /// @param market The market
    /// @param tenor The tenor
    /// @return isGreater True if the loan APR is greater than the borrow offer APRs, false otherwise
    /// @dev Perform this check in O(C * R + 1), where C is the number of subscribed collections, R is the number of rate providers, and 1 is for the user-defined APR check
    ///      Users should be aware that subscribing to too many collections / rate providers may result in market order reverts due to gas limits
    function isLoanAPRGreaterThanBorrowOfferAPRs(address user, uint256 loanAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool);

    /// @notice Get the copy loan offer config for a collection market
    /// @param collectionId The collection ID to get the copy loan offer config for
    /// @param market The market to get the copy loan offer config for
    /// @return config The copy loan offer config
    /// @dev deprecated in v1.8.1
    // function getCollectionMarketCopyLoanOfferConfig(uint256 collectionId, ISize market)
    //     external
    //     view
    //     returns (CopyLimitOrderConfig memory);

    /// @notice Get the copy borrow offer config for a collection market
    /// @param collectionId The collection ID to get the copy borrow offer config for
    /// @param market The market to get the copy borrow offer config for
    /// @return config The copy borrow offer config
    // @dev deprecated in v1.8.1
    // function getCollectionMarketCopyBorrowOfferConfig(uint256 collectionId, ISize market)
    //     external
    //     view
    //     returns (CopyLimitOrderConfig memory);

    /// @notice Get the user defined copy loan offer config for a user and collection
    /// @param user The user to get the user defined copy loan offer config for
    /// @param collectionId The collection ID to get the user defined copy loan offer config for
    /// @return config The user defined copy loan offer config for the collection
    function getUserDefinedCollectionCopyLoanOfferConfig(address user, uint256 collectionId)
        external
        view
        returns (CopyLimitOrderConfig memory);

    /// @notice Get the user defined copy borrow offer config for a user and collection
    /// @param user The user to get the user defined copy borrow offer config for
    /// @param collectionId The collection ID to get the user defined copy borrow offer config for
    /// @return config The user defined copy borrow offer config for the collection
    function getUserDefinedCollectionCopyBorrowOfferConfig(address user, uint256 collectionId)
        external
        view
        returns (CopyLimitOrderConfig memory);
}
