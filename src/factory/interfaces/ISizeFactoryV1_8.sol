// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ISizeFactoryV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory v1.8
interface ISizeFactoryV1_8 {
    /// @notice Reinitialize the factory
    /// @param users The users to reinitialize the factory for
    /// @param collectionIds The collection ids to subscribe to
    /// @dev Before v1.8, users could copy rate providers directly through `copyLimitOrders`.
    ///        In v1.8, this method was deprecated in favor of collections. The `reinitialize` function serves as a migration path
    ///        for users who are following the only off-chain collection currently offered by Size.
    function reinitialize(address[] memory users, uint256[] memory collectionIds) external;

    /// @notice Call a market with data. This can be used to batch operations on multiple markets.
    /// @param market The market to call
    /// @param data The data to call the market with
    /// @dev Anybody can do arbitrary Size calls with this function, so users MUST revoke authorizations at the end of the transaction.
    ///      Since this function executes arbitrary calls on Size markets, it should not have any trust assumptions on the ACL of factory-executed calls.
    function callMarket(ISize market, bytes calldata data) external returns (bytes memory);

    /// @notice Subscribe to collections
    /// @param collectionIds The collection ids to subscribe to
    function subscribeToCollections(uint256[] memory collectionIds) external;

    /// @notice Unsubscribe from collections
    /// @param collectionIds The collection ids to unsubscribe from
    function unsubscribeFromCollections(uint256[] memory collectionIds) external;

    /// @notice Get the loan offer APR
    /// @param user The user
    /// @param collectionId The collection id
    /// @param market The market
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return success True if the APR is valid, false otherwise
    /// @return apr The APR
    /// @dev Since v1.8, this function is moved to the SizeFactory contract as it contains the link to the CollectionsManager, where collections provide APRs for different markets through rate providers
    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (bool success, uint256 apr);

    /// @notice Get the borrow offer APR
    /// @param user The user
    /// @param collectionId The collection id
    /// @param market The market
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return success True if the APR is valid, false otherwise
    /// @return apr The APR
    /// @dev Since v1.8, this function is moved to the SizeFactory contract as it contains the link to the CollectionsManager, where collections provide APRs for different markets through rate providers
    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (bool success, uint256 apr);
}
