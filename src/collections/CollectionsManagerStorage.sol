// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

struct Collection {
    EnumerableSet.AddressSet markets;
    mapping(ISize market => EnumerableSet.AddressSet rateProvider) marketToRateProviders;
}

/// @title CollectionManagerStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @dev Introduced in v1.8
abstract contract CollectionManagerStorage {
    // collection Id counter
    uint256 collectionIdCounter;
    // mapping of curators to set of collection Ids
    mapping(address curator => EnumerableSet.UintSet collectionIds) curatorToCollectionIds;
    // mapping of collection Id to market to set of rate providers
    mapping(uint256 collectionId => mapping(ISize market => EnumerableSet.AddressSet rateProvider))
        curatorToMarketToRateProviders;
    // mapping of user to collection Ids set
    mapping(address user => EnumerableSet.UintSet collectionIds) userToCollectionIds;
}
