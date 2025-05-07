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
                            USER ACTIONS
    //////////////////////////////////////////////////////////////*/

    function subscribeUserToCollections(address user, uint256[] memory collectionIds) external onlySizeFactory {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (!isValidCollectionId(collectionIds[i])) {
                revert InvalidCollectionId(collectionIds[i]);
            }

            bool added = userToCollectionIds[user].add(collectionIds[i]);
            if (added) {
                emit SubscribedToCollection(user, collectionIds[i]);
            }
        }
    }

    function unsubscribeUserFromCollections(address user, uint256[] memory collectionIds) external onlySizeFactory {
        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (!isValidCollectionId(collectionIds[i])) {
                revert InvalidCollectionId(collectionIds[i]);
            }

            bool removed = userToCollectionIds[user].remove(collectionIds[i]);
            if (removed) {
                emit UnsubscribedFromCollection(user, collectionIds[i]);
            }
        }
    }
}
