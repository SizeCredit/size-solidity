// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

/// @title ISizeFactoryView
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory view
interface ISizeFactoryView {
    /// @notice Check if an address is a registered market
    /// @param candidate The candidate to check
    /// @return True if the candidate is a registered market
    function isMarket(address candidate) external view returns (bool);

    /// @notice Check if an address is a registered price feed
    /// @param candidate The candidate to check
    /// @return True if the candidate is a registered price feed
    function isPriceFeed(address candidate) external view returns (bool);

    /// @notice Check if an address is a registered borrow aToken
    /// @param candidate The candidate to check
    /// @return True if the candidate is a registered borrow aToken
    function isBorrowATokenV1_5(address candidate) external view returns (bool);

    /// @notice Get a market by index
    /// @dev Returns address(0) if the market does not exist
    /// @return market The market
    function getMarket(uint256 index) external view returns (ISize);

    /// @notice Get a price feed by index
    /// @dev Returns address(0) if the price feed does not exist
    /// @return priceFeed The price feed
    function getPriceFeed(uint256 index) external view returns (PriceFeed);

    /// @notice Get a borrow aToken by index
    /// @dev Returns address(0) if the borrow aToken does not exist
    /// @return borrowATokenV1_5 The borrow aToken
    function getBorrowATokenV1_5(uint256 index) external view returns (IERC20Metadata);

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

    /// @notice Get the number of markets
    /// @return count The number of markets
    function getMarketsCount() external view returns (uint256);

    /// @notice Get the number of price feeds
    /// @return count The number of price feeds
    function getPriceFeedsCount() external view returns (uint256);

    /// @notice Get the number of borrow aTokens
    /// @return count The number of borrow aTokens
    function getBorrowATokensV1_5Count() external view returns (uint256);

    /// @notice Get the contract version
    /// @return version The contract version
    function version() external pure returns (string memory);
}
