// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {CopyLimitOrderConfig} from "@src/market/libraries/OfferLibrary.sol";

struct MarketInformation {
    bool initialized;
    CopyLimitOrderConfig ___deprecated_copyLoanOfferConfig;
    CopyLimitOrderConfig ___deprecated_copyBorrowOfferConfig;
    EnumerableSet.AddressSet rateProviders;
}

struct UserCollectionCopyLimitOrderConfigs {
    CopyLimitOrderConfig copyLoanOfferConfig;
    CopyLimitOrderConfig copyBorrowOfferConfig;
}

/// @title CollectionManagerStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev Introduced in v1.8
abstract contract CollectionsManagerBase {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    // size factory
    ISizeFactory sizeFactory;
    // collection Id counter
    uint256 collectionIdCounter;
    // mapping of collection Id to collection
    mapping(uint256 collectionId => mapping(ISize market => MarketInformation marketInformation) collection) collections;
    // mapping of user to collection Ids set
    mapping(address user => EnumerableSet.UintSet collectionIds) userToCollectionIds;
    // mapping of user to collection Ids to CopyLimitOrderConfig
    mapping(
        address user
            => mapping(uint256 collectionId => UserCollectionCopyLimitOrderConfigs userCollectionCopyLimitOrderConfigs)
    ) userToCollectionCopyLimitOrderConfigs;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCollectionId(uint256 collectionId);
    error OnlySizeFactory(address user);
    error MarketNotInCollection(uint256 collectionId, address market);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySizeFactoryHasRole(bytes32 role) {
        if (!AccessControlUpgradeable(address(sizeFactory)).hasRole(role, msg.sender)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(msg.sender, role);
        }
        _;
    }

    modifier onlySizeFactory() {
        if (msg.sender != address(sizeFactory)) {
            revert OnlySizeFactory(msg.sender);
        }
        _;
    }
}
