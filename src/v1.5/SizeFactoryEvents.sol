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
    event MarketAdded(address indexed market, bool indexed existed);
    event MarketRemoved(address indexed market, bool indexed existed);
    event PriceFeedAdded(address indexed priceFeed, bool indexed existed);
    event PriceFeedRemoved(address indexed priceFeed, bool indexed existed);
    event BorrowATokenV1_5Added(address indexed borrowATokenV1_5, bool indexed existed);
    event BorrowATokenV1_5Removed(address indexed borrowATokenV1_5, bool indexed existed);

    event SetAuthorization(
        address indexed sender, address indexed operator, address indexed market, uint256 nonce, uint256 actionsBitmap
    ); // v1.7
    event RevokeAllAuthorizations(address indexed sender); // v1.7
}
