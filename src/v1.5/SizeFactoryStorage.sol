// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title SizeFactoryStorage
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
abstract contract SizeFactoryStorage {
    EnumerableSet.AddressSet internal markets;
    EnumerableSet.AddressSet internal priceFeeds;
    EnumerableSet.AddressSet internal borrowATokensV1_5;
    address public sizeImplementation;
    address public nonTransferrableScaledTokenV1_5Implementation;
}
