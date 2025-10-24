// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {UserCollectionCopyLimitOrderConfigs} from "@src/collections/CollectionsManagerBase.sol";
import {CollectionsManagerView} from "@src/collections/actions/CollectionsManagerView.sol";
import {ICollectionsManagerUserActions} from "@src/collections/interfaces/ICollectionsManagerUserActions.sol";
import {CopyLimitOrderConfig, OfferLibrary} from "@src/market/libraries/OfferLibrary.sol";

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
        CopyLimitOrderConfig memory fullCopy = CopyLimitOrderConfig({
            minTenor: 0,
            maxTenor: type(uint256).max,
            minAPR: 0,
            maxAPR: type(uint256).max,
            offsetAPR: 0
        });

        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (!isValidCollectionId(collectionIds[i])) {
                revert InvalidCollectionId(collectionIds[i]);
            }

            bool added = userToCollectionIds[user].add(collectionIds[i]);
            if (added) {
                emit SubscribedToCollection(user, collectionIds[i]);
                _setUserCollectionCopyLimitOrderConfigs(user, collectionIds[i], fullCopy, fullCopy);
            }
        }
    }

    function unsubscribeUserFromCollections(address user, uint256[] memory collectionIds) external onlySizeFactory {
        // slither-disable-next-line uninitialized-local
        CopyLimitOrderConfig memory nullCopy;

        for (uint256 i = 0; i < collectionIds.length; i++) {
            if (!isValidCollectionId(collectionIds[i])) {
                revert InvalidCollectionId(collectionIds[i]);
            }

            bool removed = userToCollectionIds[user].remove(collectionIds[i]);
            if (removed) {
                emit UnsubscribedFromCollection(user, collectionIds[i]);
                _setUserCollectionCopyLimitOrderConfigs(user, collectionIds[i], nullCopy, nullCopy);
            }
        }
    }

    function setUserCollectionCopyLimitOrderConfigs(
        address user,
        uint256 collectionId,
        CopyLimitOrderConfig memory copyLoanOfferConfig,
        CopyLimitOrderConfig memory copyBorrowOfferConfig
    ) external onlySizeFactory {
        _setUserCollectionCopyLimitOrderConfigs(user, collectionId, copyLoanOfferConfig, copyBorrowOfferConfig);
    }

    function _setUserCollectionCopyLimitOrderConfigs(
        address user,
        uint256 collectionId,
        CopyLimitOrderConfig memory copyLoanOfferConfig,
        CopyLimitOrderConfig memory copyBorrowOfferConfig
    ) internal {
        if (!isValidCollectionId(collectionId)) {
            revert InvalidCollectionId(collectionId);
        }
        OfferLibrary.validateCopyLimitOrderConfigs(copyLoanOfferConfig, copyBorrowOfferConfig);

        userToCollectionCopyLimitOrderConfigs[user][collectionId] = UserCollectionCopyLimitOrderConfigs({
            copyLoanOfferConfig: copyLoanOfferConfig,
            copyBorrowOfferConfig: copyBorrowOfferConfig
        });
        emit SetUserCollectionCopyLimitOrderConfigs(user, collectionId, copyLoanOfferConfig, copyBorrowOfferConfig);
    }
}
