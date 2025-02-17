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

import {ISizeFactoryGetters} from "@src/v1.5/interfaces/ISizeFactoryGetters.sol";
import {ISizeFactoryV1_7} from "@src/v1.5/interfaces/ISizeFactoryV1_7.sol";

/// @title ISizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory
interface ISizeFactory is ISizeFactoryGetters, ISizeFactoryV1_7 {
    /// @notice Set the size implementation
    /// @param _sizeImplementation The new size implementation
    function setSizeImplementation(address _sizeImplementation) external;

    /// @notice Set the non-transferrable scaled token v1.5 implementation
    /// @param _nonTransferrableScaledTokenV1_5Implementation The new non-transferrable scaled token v1.5 implementation
    function setNonTransferrableScaledTokenV1_5Implementation(address _nonTransferrableScaledTokenV1_5Implementation)
        external;

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
}
