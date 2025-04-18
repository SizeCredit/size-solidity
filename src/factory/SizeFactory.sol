// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Math, PERCENT} from "@src/market/libraries/Math.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/market/libraries/actions/Initialize.sol";

import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Errors} from "@src/market/libraries/Errors.sol";

import {ISize} from "@src/market/interfaces/ISize.sol";

import {ISizeFactory} from "@src/factory/interfaces/ISizeFactory.sol";
import {MarketFactoryLibrary} from "@src/factory/libraries/MarketFactoryLibrary.sol";

import {NonTransferrableTokenVaultLibrary} from "@src/factory/libraries/NonTransferrableTokenVaultLibrary.sol";
import {PriceFeedFactoryLibrary} from "@src/factory/libraries/PriceFeedFactoryLibrary.sol";
import {NonTransferrableTokenVault} from "@src/market/token/NonTransferrableTokenVault.sol";

import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {SizeFactoryEvents} from "@src/factory/SizeFactoryEvents.sol";
import {SizeFactoryOffchainGetters} from "@src/factory/SizeFactoryOffchainGetters.sol";
import {Action, ActionsBitmap, Authorization} from "@src/factory/libraries/Authorization.sol";

import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";

import {BORROW_RATE_UPDATER_ROLE, KEEPER_ROLE, PAUSER_ROLE} from "@src/factory/interfaces/ISizeFactory.sol";

/// @title SizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
/// @dev Expects `AccessControlUpgradeable` to have a single DEFAULT_ADMIN_ROLE role address set.
contract SizeFactory is
    ISizeFactory,
    SizeFactoryOffchainGetters,
    SizeFactoryEvents,
    MulticallUpgradeable,
    Ownable2StepUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __Multicall_init();
        __Ownable2Step_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _owner);
        _grantRole(KEEPER_ROLE, _owner);
        _grantRole(BORROW_RATE_UPDATER_ROLE, _owner);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /// @inheritdoc ISizeFactory
    function setSizeImplementation(address _sizeImplementation) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_sizeImplementation == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit SizeImplementationSet(sizeImplementation, _sizeImplementation);
        sizeImplementation = _sizeImplementation;
    }

    /// @inheritdoc ISizeFactory
    function setNonTransferrableTokenVaultImplementation(address _nonTransferrableTokenVaultImplementation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_nonTransferrableTokenVaultImplementation == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit NonTransferrableTokenVaultImplementationSet(
            nonTransferrableTokenVaultImplementation, _nonTransferrableTokenVaultImplementation
        );
        nonTransferrableTokenVaultImplementation = _nonTransferrableTokenVaultImplementation;
    }

    /// @inheritdoc ISizeFactory
    function createMarket(
        InitializeFeeConfigParams calldata feeConfigParams,
        InitializeRiskConfigParams calldata riskConfigParams,
        InitializeOracleParams calldata oracleParams,
        InitializeDataParams calldata dataParams
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (ISize market) {
        address admin = msg.sender;
        market = MarketFactoryLibrary.createMarket(
            sizeImplementation, admin, feeConfigParams, riskConfigParams, oracleParams, dataParams
        );
        // slither-disable-next-line unused-return
        markets.add(address(market));
        emit CreateMarket(address(market));
    }

    /// @inheritdoc ISizeFactory
    function createBorrowTokenVault(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (NonTransferrableTokenVault borrowTokenVault)
    {
        address admin = msg.sender;
        borrowTokenVault = NonTransferrableTokenVaultLibrary.createNonTransferrableTokenVault(
            nonTransferrableTokenVaultImplementation, admin, variablePool, underlyingBorrowToken
        );
        emit CreateBorrowTokenVault(address(borrowTokenVault));
    }

    /// @inheritdoc ISizeFactory
    function createPriceFeed(PriceFeedParams memory _priceFeedParams)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (PriceFeed priceFeed)
    {
        priceFeed = PriceFeedFactoryLibrary.createPriceFeed(_priceFeedParams);
        emit CreatePriceFeed(address(priceFeed));
    }

    /// @inheritdoc ISizeFactory
    function isMarket(address candidate) external view returns (bool) {
        return markets.contains(candidate);
    }

    /// @inheritdoc ISizeFactoryV1_7
    function setAuthorization(address operator, ActionsBitmap actionsBitmap) external override(ISizeFactoryV1_7) {
        // validate msg.sender
        // N/A

        // validate operator
        if (operator == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        // validate actionsBitmap
        if (!Authorization.isValid(actionsBitmap)) {
            revert Errors.INVALID_ACTIONS_BITMAP(Authorization.toUint256(actionsBitmap));
        }

        uint256 nonce = authorizationNonces[msg.sender];
        emit SetAuthorization(msg.sender, operator, Authorization.toUint256(actionsBitmap), nonce);
        authorizations[nonce][operator][msg.sender] = actionsBitmap;
    }

    /// @inheritdoc ISizeFactoryV1_7
    function revokeAllAuthorizations() external override(ISizeFactoryV1_7) {
        emit RevokeAllAuthorizations(msg.sender);
        authorizationNonces[msg.sender]++;
    }

    /// @inheritdoc ISizeFactoryV1_7
    function isAuthorized(address operator, address onBehalfOf, Action action) public view returns (bool) {
        if (operator == onBehalfOf) {
            return true;
        } else {
            uint256 nonce = authorizationNonces[onBehalfOf];
            return Authorization.isActionSet(authorizations[nonce][operator][onBehalfOf], action);
        }
    }
}
