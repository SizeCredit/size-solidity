// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISize} from "@src/interfaces/ISize.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

/// @title ISizeFactoryGetters
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory getters
interface ISizeFactoryGetters {
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
}
