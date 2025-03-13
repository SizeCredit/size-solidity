// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ActionsBitmap} from "@src/factory/libraries/Authorization.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

/// @title ISizeFactoryGetters
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory getters
interface ISizeFactoryGetters {
    /// @notice Check if an address is a registered price feed
    /// @param candidate The candidate to check
    /// @return isPriceFeed True if the candidate is a registered price feed
    function isPriceFeed(address candidate) external view returns (bool);

    /// @notice Check if an address is a registered borrow aToken
    /// @param candidate The candidate to check
    /// @return isBorrowATokenV1_5 True if the candidate is a registered borrow aToken
    function isBorrowATokenV1_5(address candidate) external view returns (bool);

    /// @notice Get a market by index
    /// @param index The index of the market
    /// @return market The market
    function getMarket(uint256 index) external view returns (ISize);

    /// @notice Get a price feed by index
    /// @param index The index of the price feed
    /// @return priceFeed The price feed
    function getPriceFeed(uint256 index) external view returns (PriceFeed);

    /// @notice Get a borrow aToken by index
    /// @param index The index of the borrow aToken
    /// @return borrowATokenV1_5 The borrow aToken
    function getBorrowATokenV1_5(uint256 index) external view returns (IERC20Metadata);

    /// @notice Get the number of markets
    /// @return marketsCount The number of markets
    function getMarketsCount() external view returns (uint256);

    /// @notice Get the number of price feeds
    /// @return priceFeedsCount The number of price feeds
    function getPriceFeedsCount() external view returns (uint256);

    /// @notice Get the number of borrow aTokens
    /// @return borrowATokensV1_5Count The number of borrow aTokens
    function getBorrowATokensV1_5Count() external view returns (uint256);

    /// @notice Get all markets
    /// @return markets The markets
    function getMarkets() external view returns (ISize[] memory);

    /// @notice Get all price feeds
    /// @return priceFeeds The price feeds
    function getPriceFeeds() external view returns (PriceFeed[] memory);

    /// @notice Get all borrow aTokens
    /// @return borrowATokensV1_5 The borrow aTokens
    function getBorrowATokensV1_5() external view returns (IERC20Metadata[] memory);

    /// @notice Get all market descriptions
    ///         The market description is Size | COLLATERALSYMBOL | BORROWSYMBOL | CRLPERCENT | VERSION,
    ///         such as Size | WETH | USDC | 130 | v1.2.1, for a ETH/USDC market with 130% CR
    /// @return descriptions The market descriptions
    function getMarketDescriptions() external view returns (string[] memory descriptions);

    /// @notice Get all price feed descriptions
    ///         The price feed description is PriceFeed | COLLATERALFEEDDESCRIPTION | BORROWFEEDDESCRIPTION,
    ///         such as PriceFeed | ETH / USD | USDC / USD, for a ETH/USDC price feed
    /// @return descriptions The price feed descriptions
    function getPriceFeedDescriptions() external view returns (string[] memory descriptions);

    /// @notice Get all borrow aToken descriptions
    ///         The borrow aToken description is SYMBOL,
    ///         such as szaUSDC for a ETH/USDC borrow aToken
    /// @return descriptions The borrow aToken descriptions
    function getBorrowATokenV1_5Descriptions() external view returns (string[] memory descriptions);

    /// @notice Check if an address is authorized for all actions
    /// @param operator The operator to check
    /// @param onBehalfOf The account on behalf of which the action is authorized
    /// @param actionsBitmap The actions bitmap
    /// @return authorized True if the address is authorized for all actions
    function isAuthorizedAll(address operator, address onBehalfOf, ActionsBitmap actionsBitmap)
        external
        view
        returns (bool);

    /// @notice Get the version of the size factory
    /// @return version The version of the size factory
    function version() external view returns (string memory);
}
