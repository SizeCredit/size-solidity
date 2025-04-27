// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";
import {NonTransferrableRebasingTokenVault} from "@src/market/token/NonTransferrableRebasingTokenVault.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {ISizeFactoryOffchainGetters} from "@src/factory/interfaces/ISizeFactoryOffchainGetters.sol";
import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";

bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
bytes32 constant BORROW_RATE_UPDATER_ROLE = keccak256("BORROW_RATE_UPDATER_ROLE");

/// @title ISizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice The interface for the size factory
interface ISizeFactory is ISizeFactoryOffchainGetters, ISizeFactoryV1_7 {
    /// @notice Set the size implementation
    /// @param _sizeImplementation The new size implementation
    function setSizeImplementation(address _sizeImplementation) external;

    /// @notice Set the non-transferrable token vault implementation
    /// @param _nonTransferrableTokenVaultImplementation The new non-transferrable token vault implementation
    function setNonTransferrableRebasingTokenVaultImplementation(address _nonTransferrableTokenVaultImplementation)
        external;

    /// @notice Creates a new market
    /// @dev The contract owner is set as the owner of the market
    function createMarket(
        InitializeFeeConfigParams calldata feeConfigParams,
        InitializeRiskConfigParams calldata riskConfigParams,
        InitializeOracleParams calldata oracleParams,
        InitializeDataParams calldata dataParams
    ) external returns (ISize);

    /// @notice Creates a new borrow token vault
    /// @dev The contract owner is set as the owner of the borrow token vault
    function createBorrowTokenVault(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        returns (NonTransferrableRebasingTokenVault);

    /// @notice Creates a new price feed
    function createPriceFeed(PriceFeedParams calldata priceFeedParams) external returns (PriceFeed);

    /// @notice Check if an address is a registered market
    /// @param candidate The candidate to check
    /// @return True if the candidate is a registered market
    function isMarket(address candidate) external view returns (bool);
}
