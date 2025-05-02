// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

struct Collection {
    address curator;
    uint256 minAPR;
    uint256 maxAPR;
    uint256 minTenor;
    uint256 maxTenor;
    EnumerableSet.AddressSet markets;
    mapping(ISize market => EnumerableSet.AddressSet rateProviders) marketToRateProviders;
}

/// @title CollectionManagerStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev Introduced in v1.8
abstract contract CollectionsManagerBase {
    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    ISizeFactory sizeFactory;
    // collection Id counter
    uint256 collectionIdCounter;
    // mapping of collection Id to collection
    mapping(uint256 collectionId => Collection collection) collections;
    // mapping of user to collection Ids set
    mapping(address user => EnumerableSet.UintSet collectionIds) userToCollectionIds;

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidCollectionId(uint256 collectionId);
}
