// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title ICollectionsManagerUserActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
interface ICollectionsManagerUserActions {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscribedToCollection(address indexed user, uint256 indexed collectionId);
    event UnsubscribedFromCollection(address indexed user, uint256 indexed collectionId);

    /*//////////////////////////////////////////////////////////////
                            ACTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Subscribe a user to collections
    /// @param user The user to subscribe
    /// @param collectionIds The collection IDs to subscribe the user to
    function subscribeUserToCollections(address user, uint256[] memory collectionIds) external;

    /// @notice Unsubscribe a user from collections
    /// @param user The user to unsubscribe
    /// @param collectionIds The collection IDs to unsubscribe the user from
    function unsubscribeUserFromCollections(address user, uint256[] memory collectionIds) external;
}
