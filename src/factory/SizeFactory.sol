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
import {NonTransferrableScaledTokenV1_5FactoryLibrary} from
    "@src/factory/libraries/NonTransferrableScaledTokenV1_5FactoryLibrary.sol";
import {PriceFeedFactoryLibrary} from "@src/factory/libraries/PriceFeedFactoryLibrary.sol";

import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

import {NonTransferrableScaledTokenV1_5} from "@src/market/token/NonTransferrableScaledTokenV1_5.sol";
import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";

import {SizeFactoryEvents} from "@src/factory/SizeFactoryEvents.sol";
import {SizeFactoryGetters} from "@src/factory/SizeFactoryGetters.sol";
import {Action, ActionsBitmap, Authorization} from "@src/factory/libraries/Authorization.sol";

import {ISizeFactoryV1_7} from "@src/factory/interfaces/ISizeFactoryV1_7.sol";

import {BORROW_RATE_UPDATER_ROLE, KEEPER_ROLE, PAUSER_ROLE} from "@src/factory/interfaces/ISizeFactory.sol";

/// @title SizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
contract SizeFactory is
    ISizeFactory,
    SizeFactoryGetters,
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

    function reinitialize() external onlyOwner reinitializer(1_7_0) {
        // grant `AccessControlUpgradeable` roles to the `Ownable2StepUpgradeable` owner
        _grantRole(DEFAULT_ADMIN_ROLE, owner());
        _grantRole(PAUSER_ROLE, owner());
        _grantRole(KEEPER_ROLE, owner());
        _grantRole(BORROW_RATE_UPDATER_ROLE, owner());
        // transfer `Ownable2StepUpgradeable` ownership to the zero address to keep the state consistent
        // in a future upgrade, we can simply remove `Ownable2StepUpgradeable` from the implementation
        _transferOwnership(address(0));
        // can only be called once
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
    function setNonTransferrableScaledTokenV1_5Implementation(address _nonTransferrableScaledTokenV1_5Implementation)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (_nonTransferrableScaledTokenV1_5Implementation == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit NonTransferrableScaledTokenV1_5ImplementationSet(
            nonTransferrableScaledTokenV1_5Implementation, _nonTransferrableScaledTokenV1_5Implementation
        );
        nonTransferrableScaledTokenV1_5Implementation = _nonTransferrableScaledTokenV1_5Implementation;
    }

    /// @inheritdoc ISizeFactory
    function createMarket(
        InitializeFeeConfigParams calldata feeConfigParams,
        InitializeRiskConfigParams calldata riskConfigParams,
        InitializeOracleParams calldata oracleParams,
        InitializeDataParams calldata dataParams
    ) external onlyRole(DEFAULT_ADMIN_ROLE) returns (ISize market) {
        market = MarketFactoryLibrary.createMarket(
            sizeImplementation, owner(), feeConfigParams, riskConfigParams, oracleParams, dataParams
        );
        _addMarket(market);
    }

    /// @inheritdoc ISizeFactory
    function addMarket(ISize market) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool existed) {
        existed = _addMarket(market);
    }

    function _addMarket(ISize market) internal returns (bool existed) {
        if (address(market) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = !markets.add(address(market));
        emit MarketAdded(address(market), existed);
    }

    /// @inheritdoc ISizeFactory
    function removeMarket(ISize market) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool existed) {
        if (address(market) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = markets.remove(address(market));
        emit MarketRemoved(address(market), existed);
    }

    function createPriceFeed(PriceFeedParams memory _priceFeedParams) external returns (PriceFeed priceFeed) {
        priceFeed = PriceFeedFactoryLibrary.createPriceFeed(_priceFeedParams);
        _addPriceFeed(priceFeed);
    }

    /// @inheritdoc ISizeFactory
    function addPriceFeed(PriceFeed priceFeed) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool existed) {
        existed = _addPriceFeed(priceFeed);
    }

    function _addPriceFeed(PriceFeed priceFeed) internal returns (bool existed) {
        if (address(priceFeed) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = !priceFeeds.add(address(priceFeed));
        emit PriceFeedAdded(address(priceFeed), existed);
    }

    /// @inheritdoc ISizeFactory
    function removePriceFeed(PriceFeed priceFeed) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool existed) {
        if (address(priceFeed) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = priceFeeds.remove(address(priceFeed));
        emit PriceFeedRemoved(address(priceFeed), existed);
    }

    /// @inheritdoc ISizeFactory
    function createBorrowATokenV1_5(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        returns (NonTransferrableScaledTokenV1_5 borrowATokenV1_5)
    {
        borrowATokenV1_5 = NonTransferrableScaledTokenV1_5FactoryLibrary.createNonTransferrableScaledTokenV1_5(
            nonTransferrableScaledTokenV1_5Implementation, owner(), variablePool, underlyingBorrowToken
        );
        _addBorrowATokenV1_5(borrowATokenV1_5);
    }

    /// @inheritdoc ISizeFactory
    function addBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool existed)
    {
        existed = _addBorrowATokenV1_5(borrowATokenV1_5);
    }

    function _addBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) internal returns (bool existed) {
        if (address(borrowATokenV1_5) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = !borrowATokensV1_5.add(address(borrowATokenV1_5));
        emit BorrowATokenV1_5Added(address(borrowATokenV1_5), existed);
    }

    /// @inheritdoc ISizeFactory
    function removeBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bool existed)
    {
        if (address(borrowATokenV1_5) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = borrowATokensV1_5.remove(address(borrowATokenV1_5));
        emit BorrowATokenV1_5Removed(address(borrowATokenV1_5), existed);
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
