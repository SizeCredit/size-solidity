// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ActionsBitmap} from "@src/factory/libraries/Authorization.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title SizeFactoryStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
// slither-disable-start uninitialized-state
// slither-disable-start constable-states
abstract contract SizeFactoryStorage {
    // the markets
    EnumerableSet.AddressSet markets;
    // deprecated in v1.7
    EnumerableSet.AddressSet ___unused_01;
    // deprecated in v1.7
    EnumerableSet.AddressSet ___unused_02;
    // the size implementation (used as implementation for proxy contracts, added on v1.6)
    address public sizeImplementation;
    // the non-transferrable token vault implementation (upgraded on v1.8)
    address public nonTransferrableTokenVaultImplementation;
    // mapping of authorized actions for operators per account (added on v1.7)
    mapping(
        uint256 nonce
            => mapping(address operator => mapping(address onBehalfOf => ActionsBitmap authorizedActionsBitmap))
    ) public authorizations;
    // mapping of authorization nonces per account (added on v1.7)
    mapping(address onBehalfOf => uint256 nonce) public authorizationNonces;
}
// slither-disable-end constable-states
// slither-disable-end uninitialized-state
