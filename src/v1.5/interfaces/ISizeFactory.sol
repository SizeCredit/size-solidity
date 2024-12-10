// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";

/// @title ISizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory
interface ISizeFactory {
    /// @notice Creates a new market
    /// @dev The contract owner is set as the owner of the market
    function createMarket(
        InitializeFeeConfigParams calldata feeConfigParams,
        InitializeRiskConfigParams calldata riskConfigParams,
        InitializeOracleParams calldata oracleParams,
        InitializeDataParams calldata dataParams
    ) external returns (ISize);

    /// @notice Creates a new price feed
    function createPriceFeed(PriceFeedParams calldata priceFeedParams) external returns (PriceFeed);

    /// @notice Creates a new borrow aToken
    function createBorrowATokenV1_5(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        returns (NonTransferrableScaledTokenV1_5);

    /// @notice Add a market to the factory
    /// @param market The market to add
    /// @return existed True if the market existed before
    function addMarket(ISize market) external returns (bool existed);

    /// @notice Add a price feed to the factory
    /// @param priceFeed The price feed to add
    /// @return existed True if the price feed existed before
    function addPriceFeed(PriceFeed priceFeed) external returns (bool existed);

    /// @notice Add a borrow aToken to the factory
    /// @param borrowATokenV1_5 The borrow aToken to add
    /// @return existed True if the borrow aToken existed before
    function addBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) external returns (bool existed);

    /// @notice Remove a market from the factory
    /// @param market The market to remove
    /// @return existed True if the market existed before
    function removeMarket(ISize market) external returns (bool existed);

    /// @notice Remove a price feed from the factory
    /// @param priceFeed The price feed to remove
    /// @return existed True if the price feed existed before
    function removePriceFeed(PriceFeed priceFeed) external returns (bool existed);

    /// @notice Remove a borrow aToken from the factory
    /// @param borrowATokenV1_5 The borrow aToken to remove
    /// @return existed True if the borrow aToken existed before
    function removeBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) external returns (bool existed);

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
