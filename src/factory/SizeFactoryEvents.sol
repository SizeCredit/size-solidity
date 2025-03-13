// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/// @title SizeFactoryEvents
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
abstract contract SizeFactoryEvents {
    event SizeImplementationSet(address indexed oldSizeImplementation, address indexed newSizeImplementation);
    event NonTransferrableScaledTokenV1_5ImplementationSet(
        address indexed oldNonTransferrableScaledTokenV1_5Implementation,
        address indexed newNonTransferrableScaledTokenV1_5Implementation
    );

    event CreateMarket(address indexed market);
    event CreatePriceFeed(address indexed priceFeed);
    event CreateBorrowATokenV1_5(address indexed borrowATokenV1_5);

    event SetAuthorization(
        address indexed sender, address indexed operator, uint256 indexed actionsBitmap, uint256 nonce
    ); // v1.7
    event RevokeAllAuthorizations(address indexed sender); // v1.7
}
