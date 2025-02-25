// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ActionsBitmap} from "@src/factory/libraries/Authorization.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";

/// @title SizeFactoryStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
abstract contract SizeFactoryStorage {
    // the markets
    EnumerableSet.AddressSet markets;
    // the price feeds
    EnumerableSet.AddressSet priceFeeds;
    // the borrow aTokens v1.5
    EnumerableSet.AddressSet borrowATokensV1_5;
    // the size implementation (used as implementation for proxy contracts, added on v1.6)
    address public sizeImplementation;
    // the non-transferrable scaled token v1.5 implementation (used as implementation for proxy contracts, added on v1.6)
    address public nonTransferrableScaledTokenV1_5Implementation;
    // mapping of authorized actions for operators per account (added on v1.7)
    mapping(
        uint256 nonce
            => mapping(address operator => mapping(address onBehalfOf => ActionsBitmap authorizedActionsBitmap))
    ) public authorizations;
    // mapping of authorization nonces per account (added on v1.7)
    mapping(address onBehalfOf => uint256 nonce) public authorizationNonces;
}
