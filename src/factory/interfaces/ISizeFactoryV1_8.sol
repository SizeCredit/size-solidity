// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ICollectionsManager} from "@src/collections/interfaces/ICollectionsManager.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title ISizeFactoryV1_8
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory v1.8
interface ISizeFactoryV1_8 {
    /// @notice Reinitialize the factory
    /// @param _collectionsManager The collections manager contract
    /// @param _users The users to reinitialize the factory for
    /// @param _curator The curator that will receive the collection
    /// @param _rateProvider The rate provider
    /// @param _collectionMarkets The markets for the collection
    /// @dev Before v1.8, users could copy rate providers directly through `copyLimitOrders`.
    ///        In v1.8, this method was deprecated in favor of collections and `setCopyLimitOrderConfigs`. The `reinitialize` function serves as a migration path
    ///        for users who are following the only off-chain collection currently offered by Size.
    ///      On mainnet, there are no off-chain collections. On Base, there is only one off-chain collection.
    ///      Although users could theoretically DoS/grief the reinitialization process by sybil copying the rate provider with multiple accounts,
    ///        these addresses are filtered on the backend by liquidity, so this is not a concern.
    function reinitialize(
        ICollectionsManager _collectionsManager,
        address[] memory _users,
        address _curator,
        address _rateProvider,
        ISize[] memory _collectionMarkets
    ) external;

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

    /// @notice Same as `subscribeToCollections` but `onBehalfOf`
    function subscribeToCollectionsOnBehalfOf(uint256[] memory collectionIds, address onBehalfOf) external;

    /// @notice Same as `unsubscribeFromCollections` but `onBehalfOf`
    function unsubscribeFromCollectionsOnBehalfOf(uint256[] memory collectionIds, address onBehalfOf) external;

    /// @notice Get the loan offer APR
    /// @param user The user
    /// @param collectionId The collection id
    /// @param market The market
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return apr The APR
    /// @dev Since v1.8, this function is moved to the SizeFactory contract as it contains the link to the CollectionsManager, where collections provide APRs for different markets through rate providers
    function getLoanOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256);

    /// @notice Get the borrow offer APR
    /// @param user The user
    /// @param collectionId The collection id
    /// @param market The market
    /// @param rateProvider The rate provider
    /// @param tenor The tenor
    /// @return apr The APR
    /// @dev Since v1.8, this function is moved to the SizeFactory contract as it contains the link to the CollectionsManager, where collections provide APRs for different markets through rate providers
    function getBorrowOfferAPR(address user, uint256 collectionId, ISize market, address rateProvider, uint256 tenor)
        external
        view
        returns (uint256);

    /// @notice Check if the borrow APR is lower than the loan offer APRs
    /// @param user The user
    /// @param borrowAPR The borrow APR
    /// @param market The market
    /// @param tenor The tenor
    /// @return isLower True if the borrow APR is lower than the loan offer APRs, false otherwise
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
    function isLoanAPRGreaterThanBorrowOfferAPRs(address user, uint256 loanAPR, ISize market, uint256 tenor)
        external
        view
        returns (bool);
}
