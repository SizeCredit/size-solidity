// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISize} from "@src/market/interfaces/ISize.sol";
import {PriceFeed} from "@src/oracle/v1.5.1/PriceFeed.sol";

/// @title ISizeFactoryGetters
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory getters. These functions are only used by offchain components.
interface ISizeFactoryOffchainGetters {
    /// @notice Get a market by index
    /// @param index The index of the market
    /// @return market The market
    function getMarket(uint256 index) external view returns (ISize);

    /// @notice Get the number of markets
    /// @return marketsCount The number of markets
    function getMarketsCount() external view returns (uint256);

    /// @notice Get all markets
    /// @return markets The markets
    function getMarkets() external view returns (ISize[] memory);

    /// @notice Get all market descriptions
    ///         The market description is Size | COLLATERALSYMBOL | BORROWSYMBOL | CRLPERCENT | VERSION,
    ///         such as Size | WETH | USDC | 130 | v1.2.1, for a ETH/USDC market with 130% CR
    /// @return descriptions The market descriptions
    function getMarketDescriptions() external view returns (string[] memory descriptions);

    /// @notice Get the version of the size factory
    /// @return version The version of the size factory
    function version() external view returns (string memory);
}
