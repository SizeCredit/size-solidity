// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Math, PERCENT} from "@src/libraries/Math.sol";
import {
    InitializeDataParams,
    InitializeFeeConfigParams,
    InitializeOracleParams,
    InitializeRiskConfigParams
} from "@src/libraries/actions/Initialize.sol";

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Errors} from "@src/libraries/Errors.sol";

import {ISize} from "@src/interfaces/ISize.sol";

import {ISizeFactory} from "@src/v1.5/interfaces/ISizeFactory.sol";
import {MarketFactoryLibrary} from "@src/v1.5/libraries/MarketFactoryLibrary.sol";
import {NonTransferrableScaledTokenV1_5FactoryLibrary} from
    "@src/v1.5/libraries/NonTransferrableScaledTokenV1_5FactoryLibrary.sol";
import {PriceFeedFactoryLibrary} from "@src/v1.5/libraries/PriceFeedFactoryLibrary.sol";

import {IPriceFeedV1_5_2} from "@src/oracle/v1.5.2/IPriceFeedV1_5_2.sol";

import {PriceFeed, PriceFeedParams} from "@src/oracle/v1.5.1/PriceFeed.sol";
import {NonTransferrableScaledTokenV1_5} from "@src/v1.5/token/NonTransferrableScaledTokenV1_5.sol";

import {SizeFactoryEvents} from "@src/v1.5/SizeFactoryEvents.sol";
import {SizeFactoryGetters} from "@src/v1.5/SizeFactoryGetters.sol";
import {Action, Authorization} from "@src/v1.5/libraries/Authorization.sol";

import {ISizeFactoryV1_7} from "@src/v1.5/interfaces/ISizeFactoryV1_7.sol";

/// @title SizeFactory
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice See the documentation in {ISizeFactory}.
contract SizeFactory is
    ISizeFactory,
    SizeFactoryGetters,
    SizeFactoryEvents,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external initializer {
        __Ownable_init(_owner);
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /// @inheritdoc ISizeFactory
    function setSizeImplementation(address _sizeImplementation) external onlyOwner {
        if (_sizeImplementation == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        emit SizeImplementationSet(sizeImplementation, _sizeImplementation);
        sizeImplementation = _sizeImplementation;
    }

    /// @inheritdoc ISizeFactory
    function setNonTransferrableScaledTokenV1_5Implementation(address _nonTransferrableScaledTokenV1_5Implementation)
        external
        onlyOwner
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
    ) external onlyOwner returns (ISize market) {
        market = MarketFactoryLibrary.createMarket(
            sizeImplementation, owner(), feeConfigParams, riskConfigParams, oracleParams, dataParams
        );
        _addMarket(market);
    }

    /// @inheritdoc ISizeFactory
    function addMarket(ISize market) external onlyOwner returns (bool existed) {
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
    function removeMarket(ISize market) external onlyOwner returns (bool existed) {
        if (address(market) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = markets.remove(address(market));
        emit MarketRemoved(address(market), existed);
    }

    function createPriceFeed(PriceFeedParams memory _priceFeedParams)
        external
        onlyOwner
        returns (PriceFeed priceFeed)
    {
        priceFeed = PriceFeedFactoryLibrary.createPriceFeed(_priceFeedParams);
        _addPriceFeed(priceFeed);
    }

    /// @inheritdoc ISizeFactory
    function addPriceFeed(PriceFeed priceFeed) external onlyOwner returns (bool existed) {
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
    function removePriceFeed(PriceFeed priceFeed) external onlyOwner returns (bool existed) {
        if (address(priceFeed) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        existed = priceFeeds.remove(address(priceFeed));
        emit PriceFeedRemoved(address(priceFeed), existed);
    }

    /// @inheritdoc ISizeFactory
    function createBorrowATokenV1_5(IPool variablePool, IERC20Metadata underlyingBorrowToken)
        external
        onlyOwner
        returns (NonTransferrableScaledTokenV1_5 borrowATokenV1_5)
    {
        borrowATokenV1_5 = NonTransferrableScaledTokenV1_5FactoryLibrary.createNonTransferrableScaledTokenV1_5(
            nonTransferrableScaledTokenV1_5Implementation, owner(), variablePool, underlyingBorrowToken
        );
        _addBorrowATokenV1_5(borrowATokenV1_5);
    }

    /// @inheritdoc ISizeFactory
    function addBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) external onlyOwner returns (bool existed) {
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
    function removeBorrowATokenV1_5(IERC20Metadata borrowATokenV1_5) external onlyOwner returns (bool existed) {
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
    function setAuthorization(address operator, address market, uint256 actionsBitmap)
        external
        override(ISizeFactoryV1_7)
    {
        // validate msg.sender
        // N/A

        // validate market
        if (market != address(0) && !markets.contains(market)) {
            revert Errors.INVALID_MARKET(market);
        }
        // validate operator
        if (operator == address(0)) {
            revert Errors.NULL_ADDRESS();
        }
        // validate actionsBitmap
        uint256 maxBitmap = (1 << (uint256(Action.LAST_ACTION))) - 1;
        if (actionsBitmap > maxBitmap) {
            revert Errors.INVALID_ACTIONS_BITMAP(actionsBitmap);
        }

        uint256 nonce = authorizationNonces[msg.sender];
        emit SetAuthorization(msg.sender, operator, market, nonce, actionsBitmap);
        authorizations[nonce][operator][msg.sender][market] = actionsBitmap;
    }

    /// @inheritdoc ISizeFactoryV1_7
    function revokeAllAuthorizations() external override(ISizeFactoryV1_7) {
        emit RevokeAllAuthorizations(msg.sender);
        authorizationNonces[msg.sender]++;
    }

    /// @inheritdoc ISizeFactoryV1_7
    function isAuthorized(address operator, address onBehalfOf, address market, Action action)
        public
        view
        returns (bool)
    {
        if (operator == onBehalfOf) {
            return true;
        } else {
            // TODO if all markets is turned off, then specific market is still authorized

            uint256 actionsBitmap = Authorization.getActionsBitmap(action);

            uint256 nonce = authorizationNonces[onBehalfOf];

            mapping(address market => uint256 authorizedActionsBitmap) storage authorizationsPerMarket =
                authorizations[nonce][operator][onBehalfOf];

            bool operatorAuthorizedOnSpecificMarket = (authorizationsPerMarket[market] & actionsBitmap) != 0;
            bool operatorAuthorizedOnAllMarkets = (authorizationsPerMarket[address(0)] & actionsBitmap) != 0;

            return operatorAuthorizedOnSpecificMarket || operatorAuthorizedOnAllMarkets;
        }
    }

    /// @inheritdoc ISizeFactoryV1_7
    function isAuthorizedOnThisMarket(address operator, address onBehalfOf, Action action) public view returns (bool) {
        address market = msg.sender;
        if (!markets.contains(market)) {
            return false;
        } else {
            return isAuthorized(operator, onBehalfOf, market, action);
        }
    }
}
