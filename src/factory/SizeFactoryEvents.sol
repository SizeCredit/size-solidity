// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title SizeFactoryEvents
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
abstract contract SizeFactoryEvents {
    event SizeImplementationSet(address indexed oldSizeImplementation, address indexed newSizeImplementation);

    event CreateMarket(address indexed market);
    event CreatePriceFeed(address indexed priceFeed);

    event SetAuthorization(
        address indexed sender, address indexed operator, uint256 indexed actionsBitmap, uint256 nonce
    ); // v1.7
    event RevokeAllAuthorizations(address indexed sender); // v1.7

    event AddVault(address indexed vault, bool existed); // v1.8
    event RemoveVault(address indexed vault, bool existed); // v1.8
}
