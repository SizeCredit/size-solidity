// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {CollectionsManagerView} from "@src/collections/actions/CollectionsManagerView.sol";
import {ICollectionsManagerUserActions} from "@src/collections/interfaces/ICollectionsManagerUserActions.sol";

/// @title CollectionsManagerUserActions
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ICollectionsManagerUserActions}.
abstract contract CollectionsManagerUserActions is ICollectionsManagerUserActions, CollectionsManagerView {
    using EnumerableSet for EnumerableSet.UintSet;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscribedToCollection(address indexed user, uint256 indexed collectionId);
    event UnsubscribedFromCollection(address indexed user, uint256 indexed collectionId);

    /*//////////////////////////////////////////////////////////////
                            USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function subscribeToCollections(uint256[] memory collectionIds) external {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (!isValidCollectionId(collectionIds[i])) {
                revert();
            }

            bool added = userToCollectionIds[msg.sender].add(collectionIds[i]);
            if (added) {
                emit SubscribedToCollection(msg.sender, collectionIds[i]);
            }
        }
    }

    function unsubscribeFromCollections(uint256[] memory collectionIds) external {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (!isValidCollectionId(collectionIds[i])) {
                revert();
            }

            bool removed = userToCollectionIds[msg.sender].remove(collectionIds[i]);
            if (removed) {
                emit UnsubscribedFromCollection(msg.sender, collectionIds[i]);
            }
        }
    }
}
