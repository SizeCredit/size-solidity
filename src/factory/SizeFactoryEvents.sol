// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title SizeFactoryEvents
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
abstract contract SizeFactoryEvents {
    event SizeImplementationSet(address indexed oldSizeImplementation, address indexed newSizeImplementation);
    event NonTransferrableRebasingTokenVaultImplementationSet(
        address indexed oldNonTransferrableRebasingTokenVaultImplementation,
        address indexed newNonTransferrableRebasingTokenVaultImplementation
    ); // v1.8

    event CreateMarket(address indexed market);
    event CreatePriceFeed(address indexed priceFeed);
    event CreateBorrowTokenVault(address indexed borrowTokenVault); // v1.8

    event SetAuthorization(
        address indexed sender, address indexed operator, uint256 indexed actionsBitmap, uint256 nonce
    ); // v1.7
    event RevokeAllAuthorizations(address indexed sender); // v1.7
}
